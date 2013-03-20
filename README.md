Basic overview for adding SMS support to Zendesk.

Set up your .env file
 1. Rename '.env.sample' to '.env.
 2. Set the values for TWILIO_ACCOUNT_SID and TWILIO_AUTH_TOKEN
    These are found here: 
 3. Set the value for TWILIO_FROM_NUMBER to a number from your Twilio account
    You can see your list of Twilio numbers here:
 4. Set the value for ZENDESK_URL to your Zendesk URL.
    It should look like this: https://{your zendesk accout}.zendesk.com/api/v2
 5. Create a dedicated "SMS User" in Zendesk, set the values for ZENDESK_USERNAME and ZENDESK_PASSWORD to the credentials for that user.


Push to and configure Heroku:
 1. Create a new Heroku app
    heroku create
 2. Push this code to Heroku
    git push heroku master
 3. Configure your Heroku app with the settings from above
    heroku config:set RACK_ENV="" TWILIO_ACCOUNT_SID="" TWILIO_AUTH_TOKEN="" TWILIO_FROM_NUMBER="" ZENDESK_URL="" ZENDESK_USERNAME="" ZENDESK_PASSWORD=""
 4. Open your new Heroku app
    heroku open

Create Triggers in Zendesk


Create a new SMS Target in Zendesk