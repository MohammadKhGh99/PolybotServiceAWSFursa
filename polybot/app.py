import flask
from flask import request
import json
import os
from bot import ObjectDetectionBot
import boto3
from botocore.exceptions import ClientError

app = flask.Flask(__name__)


# load TELEGRAM_TOKEN value from Secret Manager
client = boto3.session.Session().client(service_name="secretsmanager",
                                        region_name="us-east-1")
try:
    response = client.get_secret_value(SecretId="mgh-secrets")
except ClientError as e:
    raise e

TELEGRAM_TOKEN = json.loads(response['SecretString'])['TELEGRAM_TOKEN']
TELEGRAM_APP_URL = os.environ['TELEGRAM_APP_URL']


@app.route('/', methods=['GET'])
def index():
    return 'Ok'


@app.route(f'/{TELEGRAM_TOKEN}/', methods=['POST'])
def webhook():
    req = request.get_json()
    bot.handle_message(req['message'])
    return 'Ok'


@app.route(f'/results', methods=['POST'])
def results():
    prediction_id = request.args.get('predictionId')

    # use the prediction_id to retrieve results from DynamoDB and send to the end-user
    # create a DynamoDB resource object
    dynamodb = boto3.resource('dynamodb', region_name="us-east-1")

    # Specify the name of your DynamoDB table
    table = dynamodb.Table('mgh-objects-detection')

    # retrieve results from DynamoDB
    table_response = table.get_item(
        Key={
            'prediction_id': prediction_id,
        }
    )

    item = table_response['Item']
    print(item)
    chat_id = prediction_id
    text_results = item

    bot.send_text(chat_id, text_results)
    return 'Ok'


@app.route(f'/loadTest/', methods=['POST'])
def load_test():
    req = request.get_json()
    bot.handle_message(req['message'])
    return 'Ok'


if __name__ == "__main__":
    bot = ObjectDetectionBot(TELEGRAM_TOKEN, TELEGRAM_APP_URL)
    ssl_context = ('cert.pem', 'private.key')
    app.run(host='0.0.0.0', port=8443, ssl_context=ssl_context)
