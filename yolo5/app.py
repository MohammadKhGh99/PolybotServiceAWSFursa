import json
import time
from pathlib import Path

import requests
from detect import run
import yaml
from loguru import logger
import os
import boto3

images_bucket = os.environ['BUCKET_NAME']
queue_name = os.environ['SQS_QUEUE_NAME']

sqs_client = boto3.client('sqs', region_name='us-east-1')

with open("data/coco128.yaml", "r") as stream:
    names = yaml.safe_load(stream)['names']


def consume():
    while True:
        response = sqs_client.receive_message(QueueUrl=queue_name,
                                              MaxNumberOfMessages=1,
                                              WaitTimeSeconds=5)

        if 'Messages' in response:
            message = response['Messages'][0]['Body']
            receipt_handle = response['Messages'][0]['ReceiptHandle']
            logger.info(f"message:   {response['Messages'][0]}")

            # Use the ReceiptHandle as a prediction UUID
            prediction_id = response['Messages'][0]['MessageId']

            logger.info(f'prediction: {prediction_id}. start processing')

            # Receives a URL parameter representing
            # the image to download from S3
            message = json.loads(message)

            img_name = message["imgName"]
            chat_id = message["chat_id"]

            # download img_name from S3,
            # store the local image path in original_img_path
            try:
                session = boto3.Session()
                s3 = session.client('s3', 'us-east-1')
                local_img_path = f'{img_name}'
                s3.download_file(images_bucket, img_name, local_img_path)
            except Exception as e:
                logger.error(
                    f'prediction: {prediction_id}. '
                    f'Error downloading image from S3: {e}')
                return (f'prediction: {prediction_id}. '
                        f'Error downloading image from S3: {e}'), 404

            original_img_path = local_img_path

            logger.info(f'prediction: {prediction_id}/{original_img_path}. '
                        f'Download img completed')

            # Predicts the objects in the image
            run(
                weights='yolov5s.pt',
                data='data/coco128.yaml',
                source=original_img_path,
                project='static/data',
                name=prediction_id,
                save_txt=True
            )

            logger.info(f'prediction: {prediction_id}/{original_img_path}. done')

            # This is the path for the predicted image with labels
            # The predicted image typically includes bounding boxes drawn
            # around the detected objects, along with class labels
            # and possibly confidence scores.
            predicted_img_path = Path(f'static/data/{prediction_id}/'
                                      f'{original_img_path}')

            # Uploads the predicted image (predicted_img_path) to S3
            # (be careful not to override the original image).
            try:
                s3.upload_file(predicted_img_path, images_bucket,
                               f'{img_name.split(".")[0]}_predicted.'
                               f'{img_name.split(".")[1]}')
            except Exception as e:
                logger.error(
                    f'prediction: {prediction_id}. '
                    f'Error uploading image to S3: {e}')
                return (f'prediction: {prediction_id}. '
                        f'Error uploading image to S3: {e}'), 404

            # Parse prediction labels and create a summary
            pred_summary_path = Path(f'static/data/{prediction_id}/labels/'
                                     f'{original_img_path.split(".")[0]}.txt')
            if pred_summary_path.exists():
                with open(pred_summary_path) as f:
                    labels = f.read().splitlines()
                    labels = [line.split(' ') for line in labels]
                    labels = [{
                        'class': names[int(l[0])],
                        'cx': float(l[1]),
                        'cy': float(l[2]),
                        'width': float(l[3]),
                        'height': float(l[4]),
                    } for l in labels]

                logger.info(f'prediction: {prediction_id}/{original_img_path}.'
                            f' prediction summary:\n\n{labels}')

                prediction_summary = {
                    'prediction_id': {"S": prediction_id},
                    'original_img_path': {"S": original_img_path},
                    'predicted_img_path': {"S": str(predicted_img_path)},
                    'labels': {"SS": [str(label) for label in labels]},
                    'time': {"S": str(time.time())}
                }

                # store the prediction_summary in a DynamoDB table
                try:
                    client = boto3.client('dynamodb', region_name='us-east-1')
                    response = client.put_item(
                        TableName='mgh-objects-detection',
                        Item=prediction_summary
                    )
                    logger.info(f'response for storing prediction summary: {response}')
                except Exception as e:
                    logger.error(f'prediction: {prediction_id}. Error storing prediction summary: {e}')
                    return f'prediction: {prediction_id}. Error storing prediction summary: {e}', 404

                # perform a POST request to Polybot to `/results` endpoint
                params = {
                    'predictionId': prediction_id,
                    'chatId': chat_id
                }
                requests.post('http://alb.mohammadgh.click/results',
                              params=params)

                logger.info("POST request made to Polybot")

            # Del the message from the queue as the job is considered as DONE
            sqs_client.delete_message(QueueUrl=queue_name,
                                      ReceiptHandle=receipt_handle)
            logger.info(f'prediction: {prediction_id}. '
                        f'Message deleted from the queue')


if __name__ == "__main__":
    consume()
