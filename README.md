Basic overview for adding SMS support to Zendesk.
=================================================

Basic steps to get bidirectional SMS support in Zendesk via Twilio:

 1. If you don't have one already, create a Zendesk account.
 2. Add a new user to your account. Call this user "SMS User"
 3. Create a new Heroku app
 4. Create a new SMS Target in Zendesk
 5. Create a new Trigger in Zendesk
 6. Buy a new Twilio number and configure it
 7. Set up your .env file
 8. Push code to Heroku

Add a user named "SMS User" to your account
-------------------------------------------

 * Click on the "+ add" menu on the upper left of your Zendesk screen
 * Select the "User" option
 * Set the name as "SMS User" and give it a working email on your domain.
   (I suggest using your.email.address+sms@example.com)
 * (does this need to be an admin user?)
 * Check your email for the confirmaion link for the SMS user. Click the link.
 * Set the password for the SMS user.
 * Log back in to Zendesk with a user that has administration privileges.
 * *Gear > People (found under "Manage")*
 * Find the "SMS User", click "edit"
 * On the left, change the Role to: "Agent"

Create a new Heroku app
-----------------------------

 1. Create a new Heroku app

        heroku create

Create a new SMS Target in Zendesk
----------------------------------
 * *Gear > Extensions (found under "Settings") > Targets*
 * Select "URL target"
 * Configure the URL target as follows:
   Title: Outbound SMS target
   URL:

        http://your-app.example.com/outgoing?To={{ticket.requester.phone}}&Body={{ticket.latest_public_comment}}

   Method: POST
   Attribute Name: Details
   Basic Authentication: (leave blank)
 * Change the dropdown from "Test Target" to "Create target"
 * Click "Submit"

Create Triggers in Zendesk
--------------------------

 * *Gear > Triggers (found under "Business Rules")
 * Click "add trigger"
 * Give the trigger the title: "SMS user on Ticket Update".
 * Configure this trigger to meet all the following conditions:
   * Ticket is: Updated
   * Comment is: Present, and requester can see the comment
   * Current user: is not: "SMS User"
 * Configure this trigger to perform these actions:
   * Notify target: Outbound SMS target
 * Click "Create trigger"

Other triggers to consider implementing:

 * Send SMS to user on ticket update
 * Re-open updated tickets

Buy a new Twilio number and configure it
----------------------------------------
 * Log in to your Twilio account
 * Click "Numbers"
 * Click "Buy a number"
 * Select a number and click "Buy"
 * Buy the number
 * Click "Setup number"
 * Set the SMS Request URL to: http://your-heroku-app.example.com/sms
 * Click "Save Changes"


Set up your .env file
---------------------

 1. Rename '.env.sample' to '.env.

 2. Set the values for TWILIO_ACCOUNT_SID and TWILIO_AUTH_TOKEN
    These are found here: 

 3. Set the value for TWILIO_FROM_NUMBER to a number from your Twilio account
    You can see your list of Twilio numbers here:

 4. Set the value for ZENDESK_URL to your ZenDesk URL.
    It should look like this: https://{your zendesk accout}.zendesk.com/api/v2

 5. Create a dedicated "SMS User" in ZenDesk, 
    set the values for ZENDESK_USERNAME and ZENDESK_PASSWORD
    to the credentials for that user.


Push to and configure Heroku:
-----------------------------

 1. Make sure that your configuration is correct:

        foreman start

    If you don't get any errors then:

 2. Push the code to Heroku

        git push heroku master

 3. Configure your Heroku app with the settings from above

        heroku config:set `cat .env | tr "\n" ' '`

     Which is the same thing as doing:

        heroku config:set RACK_ENV="" 
        heroku config:set TWILIO_ACCOUNT_SID="" 
        heroku config:set TWILIO_AUTH_TOKEN="" 
        heroku config:set TWILIO_FROM_NUMBER="" 
        heroku config:set ZENDESK_URL="" 
        heroku config:set ZENDESK_USERNAME="" 
        heroku config:set ZENDESK_PASSWORD=""

 4. Open your new Heroku app

        heroku open

 5. If you see "Hello." in your web browser, then try sending your Twilio phone number an SMS.
