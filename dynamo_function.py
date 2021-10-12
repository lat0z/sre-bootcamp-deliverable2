import json
import urllib.parse
import boto3

print('Loading function')

s3 = boto3.client('s3')


def lambda_handler(event, context):
    bucket = event['Records'][0]['s3']['bucket']['name']
    key = urllib.parse.unquote_plus(event['Records'][0]['s3']['object']['key'], encoding='utf-8')
    body = ""
    try:
        response = s3.get_object(Bucket=bucket, Key=key)    
        body = response['Body'].read().decode('utf-8')
        for record in json.loads(body):
            username = record['username']
            role = record['role']
            print(f"Adding DynamoDB ITEM user:{username}, role:{role}")
            boto3.client("dynamodb").put_item(TableName="users",Item=record)
    except Exception as e:
        print(e)
        print('Error getting object {} from bucket {}. Make sure they exist and your bucket is in the same region as this function.'.format(key, bucket))
        raise e
    
