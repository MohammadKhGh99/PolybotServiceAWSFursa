import json
import boto3
import telebot
from loguru import logger
import os
import time
from telebot.types import InputFile


class Bot:

    def __init__(self, token, telegram_chat_url):
        # create a new instance of the TeleBot class.
        # all communication with Telegram servers are done using self.telegram_bot_client
        self.telegram_bot_client = telebot.TeleBot(token)

        # remove any existing webhooks configured in Telegram servers
        self.telegram_bot_client.remove_webhook()
        time.sleep(0.5)

        # set the webhook URL
        self.telegram_bot_client.set_webhook(url=f'{telegram_chat_url}/'
                                                 f'{token}/', timeout=60,
                                             certificate=open("cert.pem", "r"))

        logger.info(f'Telegram Bot information\n\n{self.telegram_bot_client.get_me()}')

    def send_text(self, chat_id, text):
        self.telegram_bot_client.send_message(chat_id, text)

    def send_text_with_quote(self, chat_id, text, quoted_msg_id):
        self.telegram_bot_client.send_message(chat_id, text, reply_to_message_id=quoted_msg_id)

    def is_current_msg_photo(self, msg):
        return 'photo' in msg

    def download_user_photo(self, msg):
        """
        Downloads the photos that sent to the Bot to `photos` directory (should be existed)
        :return:
        """
        if not self.is_current_msg_photo(msg):
            raise RuntimeError(f'Message content of type \'photo\' expected')

        file_info = self.telegram_bot_client.get_file(msg['photo'][-1]['file_id'])
        data = self.telegram_bot_client.download_file(file_info.file_path)
        folder_name = file_info.file_path.split('/')[0]

        if not os.path.exists(folder_name):
            os.makedirs(folder_name)

        with open(file_info.file_path, 'wb') as photo:
            photo.write(data)

        return file_info.file_path

    def send_photo(self, chat_id, img_path):
        if not os.path.exists(img_path):
            raise RuntimeError("Image path doesn't exist")

        self.telegram_bot_client.send_photo(
            chat_id,
            InputFile(img_path)
        )

    def handle_message(self, msg):
        """Bot Main message handler"""
        logger.info(f'Incoming message: {msg}')
        self.send_text(msg['chat']['id'], f'Your original message: {msg["text"]}')


class ObjectDetectionBot(Bot):
    def handle_message(self, msg):
        logger.info(f'Incoming message: {msg}')
        usage_msg = 'Please send a photo to start object detection'
        if "text" in msg:
            if msg["text"] == '/start':
                self.send_text(msg['chat']['id'], 'Welcome to Object '
                                                  'Detection Bot!\n'
                                                  f'{usage_msg}')
            else:
                self.send_text(msg['chat']['id'], usage_msg)
        elif self.is_current_msg_photo(msg):
            self.send_text(msg['chat']['id'],
                           "Your image is being processed. Please wait...")
            photo_path = self.download_user_photo(msg)

            # upload the photo to S3
            logger.info(f'Uploading photo to S3: {photo_path}')
            try:
                session = boto3.Session()
                s3 = session.client('s3', 'us-east-1')
                bucket_name = os.getenv('BUCKET_NAME')
                s3.upload_file(photo_path, bucket_name,
                               f"{os.path.basename(photo_path)}")
                logger.info(f'Photo uploaded to S3: {photo_path}')
            except Exception as e:
                logger.error(f'Error uploading image to S3: {e}')
                self.send_text(msg['chat']['id'],
                               f'Error uploading image to S3: {e}')
                return

            # send a job to the SQS queue
            try:
                logger.info('Sending message to SQS')
                sqs = boto3.client('sqs', region_name='us-east-1')
                queue_url = 'https://sqs.us-east-1.amazonaws.com/700935310038/mgh-objects-detection-events'
                message = {
                    'imgName': os.path.basename(photo_path),
                    'chat_id': msg['chat']['id']
                }
                sqs.send_message(
                    QueueUrl=queue_url,
                    MessageBody=json.dumps(message)
                )
                logger.info('message sent to SQS')
            except Exception as e:
                logger.error(f'Error sending message to SQS: {e}')
                self.send_text(msg['chat']['id'],
                               f'Error sending message to SQS: {e}')
                return
            # objects_rows = response.text.split('{\'class\':')
            # msg_to_send = (f"We have found {len(objects_rows) - 1} objects "
            #                f"in the image\n\n")
            # msg_to_send += "Detected Objects:\n"
            # objects = {}
            #
            # # first row has no object
            # for row in objects_rows[1:]:
            #     object_name = row.split('\'')[1].strip()
            #     if object_name in objects:
            #         objects[object_name] += 1
            #     else:
            #         objects[object_name] = 1
            #
            # for object_name, count in objects.items():
            #     if count > 1:
            #         msg_to_send += f'{object_name}s: {count}\n'
            #     else:
            #         msg_to_send += f'{object_name}: {count}\n'
            #
            # msg_to_send += "\nObject Detection completed!"

            # self.send_text(msg['chat']['id'], msg_to_send)
        else:
            self.send_text(msg['chat']['id'], usage_msg)