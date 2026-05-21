import twilio from 'twilio';

const accountSid = process.env.TWILIO_ACCOUNT_SID;
const authToken = process.env.TWILIO_AUTH_TOKEN;
const twilioNumber = process.env.TWILIO_PHONE_NUMBER;
const mainAccountSid = process.env.TWILIO_MAIN_ACCOUNT_SID; // Required if using API Key (SK...)

// Initialize Twilio client lazily to avoid build-time errors
let client: any;

function getTwilioClient() {
  if (client) return client;

  if (!accountSid || !authToken) {
    console.error('❌ Twilio credentials missing in environment variables');
    return null;
  }

  try {
    if (accountSid.startsWith('SK')) {
      // If using API Key (SK...), we MUST have the main Account SID (AC...)
      if (!mainAccountSid) {
        console.error('❌ TWILIO_MAIN_ACCOUNT_SID (starting with AC...) is required when using an API Key (SK...)');
        return null;
      }
      client = twilio(accountSid, authToken, { accountSid: mainAccountSid });
    } else {
      // Standard initialization with Account SID (AC...) and Auth Token
      client = twilio(accountSid, authToken);
    }
    return client;
  } catch (error) {
    console.error('❌ Failed to initialize Twilio client:', error);
    return null;
  }
}

export async function sendOTPSMS(phone: string, otp: string): Promise<boolean> {
  try {
    const twilioClient = getTwilioClient();
    
    // Ensure phone number is in E.164 format
    let formattedPhone = phone.trim();
    if (!formattedPhone.startsWith('+')) {
      // Default to Morocco if it starts with 0 and has 10 digits
      if (formattedPhone.startsWith('0') && formattedPhone.length === 10) {
        formattedPhone = '+212' + formattedPhone.substring(1);
      } else {
        // Just add + if missing, but it might still fail if no country code
        formattedPhone = '+' + formattedPhone;
      }
    }

    if (!twilioClient) {
      console.error('❌ Twilio client not initialized');
      return false;
    }

    const message = await twilioClient.messages.create({
      body: `Your OrdoGo verification code is: ${otp}. Valid for 10 minutes.`,
      from: twilioNumber,
      to: formattedPhone,
    });

    console.log(`✅ OTP SMS sent to ${formattedPhone}, SID: ${message.sid}`);
    return true;
  } catch (error) {
    console.error('❌ Failed to send OTP SMS:', error);
    return false;
  }
}
