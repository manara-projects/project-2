import boto3
from PIL import Image
import os
from io import BytesIO
import sys
print("PYTHONPATH:", sys.path)


s3 = boto3.client('s3')

def lambda_handler(event, context):
    for record in event['Records']:
        bucket_name = record['s3']['bucket']['name']
        object_key = record['s3']['object']['key']

        # Define the destination bucket and prefix for resized images
        destination_bucket = 'ahmed-elhgawy-resized-image' # Replace with your destination bucket
        resized_prefix = 'resized/'

        try:
            # Get the image from S3
            response = s3.get_object(Bucket=bucket_name, Key=object_key)
            image_content = response['Body'].read()

            # Open the image using Pillow
            img = Image.open(BytesIO(image_content))

            # Define the desired size (e.g., 200x200)
            # You can also calculate new dimensions while maintaining aspect ratio
            # For example:
            # max_size = 200
            # img.thumbnail((max_size, max_size))
            resized_dimensions = (200, 200) 
            resized_img = img.resize(resized_dimensions)

            # Save the resized image to a BytesIO object
            buffer = BytesIO()
            # Determine format based on original, or set a default
            original_format = img.format if img.format else 'JPEG' 
            resized_img.save(buffer, format=original_format)
            buffer.seek(0)

            # Upload the resized image to the destination S3 bucket
            resized_key = os.path.join(resized_prefix, os.path.basename(object_key))
            s3.put_object(Bucket=destination_bucket, Key=resized_key, Body=buffer, ContentType=response['ContentType'])

            print(f"Successfully resized {object_key} and saved to {destination_bucket}/{resized_key}")

        except Exception as e:
            print(f"Error processing {object_key}: {e}")
            raise e