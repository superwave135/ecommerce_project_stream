"""
Lambda Data Generator for E-commerce Click and Checkout Events
Generates realistic click and checkout events and sends to Kinesis streams
"""

import json
import os
import random
import time
import string
from datetime import datetime, timedelta
from decimal import Decimal
import boto3

# Initialize AWS clients
kinesis_client = boto3.client('kinesis')

# Environment variables
CLICKS_STREAM = os.environ.get('CLICKS_STREAM_NAME', 'ecommerce-clicks')
CHECKOUTS_STREAM = os.environ.get('CHECKOUTS_STREAM_NAME', 'ecommerce-checkouts')
EVENTS_PER_INVOCATION = int(os.environ.get('EVENTS_PER_INVOCATION', '100'))

# Product catalog
PRODUCT_CATEGORIES = ["Electronics", "Clothing", "Home", "Books", "Sports", "Toys", "Beauty", "Garden"]
PRODUCT_NAMES = [
    "Premium Widget", "Smart Device", "Comfort Essential", "Pro Series",
    "Deluxe Edition", "Classic Collection", "Modern Design", "Value Pack",
    "Elite Model", "Standard Bundle", "Advanced Kit", "Basic Set",
    "Professional Grade", "Economy Choice", "Luxury Line", "Everyday Essential"
]

PRODUCTS = [
    {
        "product_id": f"PROD-{i:04d}",
        "name": f"{random.choice(PRODUCT_NAMES)} {i}",
        "category": random.choice(PRODUCT_CATEGORIES),
        "price": round(random.uniform(9.99, 999.99), 2)
    }
    for i in range(1, 51)
]

# User pool (simulating 500 users)
USER_IDS = [f"USER-{i:05d}" for i in range(1, 501)]

# Cities and states for addresses
CITIES = ["New York", "Los Angeles", "Chicago", "Houston", "Phoenix", "Philadelphia", 
          "San Antonio", "San Diego", "Dallas", "San Jose"]
STATES = ["NY", "CA", "IL", "TX", "AZ", "PA", "FL", "OH", "GA", "NC"]


class DecimalEncoder(json.JSONEncoder):
    """Custom JSON encoder for Decimal types"""
    def default(self, obj):
        if isinstance(obj, Decimal):
            return float(obj)
        return super(DecimalEncoder, self).default(obj)


def generate_zip_code():
    """Generate a random 5-digit zip code"""
    return ''.join(random.choices(string.digits, k=5))


def generate_click_event():
    """Generate a realistic click event"""
    user_id = random.choice(USER_IDS)
    product = random.choice(PRODUCTS)
    
    return {
        'event_id': f"CLICK-{int(time.time() * 1000)}-{random.randint(1000, 9999)}",
        'user_id': user_id,
        'product_id': product['product_id'],
        'product_name': product['name'],
        'product_category': product['category'],
        'product_price': product['price'],
        'timestamp': datetime.utcnow().isoformat() + 'Z',
        'session_id': f"SESSION-{random.randint(100000, 999999)}",
        'device_type': random.choice(['desktop', 'mobile', 'tablet']),
        'page_url': f"/products/{product['product_id']}",
        'referrer': random.choice(['google', 'facebook', 'direct', 'email', 'organic'])
    }


def generate_checkout_event():
    """Generate a realistic checkout event (with lower probability than clicks)"""
    user_id = random.choice(USER_IDS)
    num_items = random.randint(1, 5)
    items = random.sample(PRODUCTS, num_items)
    
    total_amount = sum(item['price'] for item in items)
    
    return {
        'event_id': f"CHECKOUT-{int(time.time() * 1000)}-{random.randint(1000, 9999)}",
        'user_id': user_id,
        'timestamp': datetime.utcnow().isoformat() + 'Z',
        'session_id': f"SESSION-{random.randint(100000, 999999)}",
        'items': [
            {
                'product_id': item['product_id'],
                'product_name': item['name'],
                'price': item['price'],
                'quantity': 1
            } for item in items
        ],
        'total_amount': round(total_amount, 2),
        'payment_method': random.choice(['credit_card', 'debit_card', 'paypal', 'apple_pay']),
        'shipping_address': {
            'city': random.choice(CITIES),
            'state': random.choice(STATES),
            'country': 'US',
            'zip_code': generate_zip_code()
        }
    }


def send_to_kinesis(stream_name, data, partition_key):
    """Send data to Kinesis stream with error handling"""
    try:
        response = kinesis_client.put_record(
            StreamName=stream_name,
            Data=json.dumps(data, cls=DecimalEncoder),
            PartitionKey=partition_key
        )
        return response
    except Exception as e:
        print(f"Error sending to Kinesis: {str(e)}")
        raise


def lambda_handler(event, context):
    """
    Main Lambda handler
    Generates click and checkout events and sends to respective Kinesis streams
    """
    try:
        click_count = 0
        checkout_count = 0
        errors = []
        
        print(f"Starting data generation: {EVENTS_PER_INVOCATION} events")
        
        for i in range(EVENTS_PER_INVOCATION):
            # Generate mostly clicks (80%) and some checkouts (20%)
            if random.random() < 0.8:
                # Generate click event
                click_event = generate_click_event()
                try:
                    send_to_kinesis(
                        stream_name=CLICKS_STREAM,
                        data=click_event,
                        partition_key=click_event['user_id']
                    )
                    click_count += 1
                except Exception as e:
                    errors.append(f"Click event error: {str(e)}")
            else:
                # Generate checkout event
                checkout_event = generate_checkout_event()
                try:
                    send_to_kinesis(
                        stream_name=CHECKOUTS_STREAM,
                        data=checkout_event,
                        partition_key=checkout_event['user_id']
                    )
                    checkout_count += 1
                except Exception as e:
                    errors.append(f"Checkout event error: {str(e)}")
            
            # Small delay to avoid throttling
            if i % 10 == 0:
                time.sleep(0.1)
        
        result = {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Data generation completed',
                'clicks_generated': click_count,
                'checkouts_generated': checkout_count,
                'total_events': click_count + checkout_count,
                'errors': len(errors),
                'timestamp': datetime.utcnow().isoformat()
            })
        }
        
        print(f"Generation complete: {click_count} clicks, {checkout_count} checkouts")
        
        if errors:
            print(f"Errors encountered: {errors}")
        
        return result
        
    except Exception as e:
        print(f"Lambda execution error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'message': 'Error in data generation',
                'error': str(e),
                'timestamp': datetime.utcnow().isoformat()
            })
        }
