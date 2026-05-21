import twilio from 'twilio';

const accountSid = process.env.TWILIO_ACCOUNT_SID;
const authToken = process.env.TWILIO_AUTH_TOKEN;
const twilioNumber = process.env.TWILIO_PHONE_NUMBER;

// Initialize Twilio client
let client: any;
if (accountSid && authToken) {
  client = twilio(accountSid, authToken);
} else {
  console.error('❌ Twilio credentials missing in environment variables');
}

export async function sendOTPSMS(phone: string, otp: string): Promise<boolean> {
  try {
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

    if (!client) {
      // Development bypass: If no Twilio credentials, log to console and return true
      if (process.env.NODE_ENV === 'development' || !process.env.TWILIO_ACCOUNT_SID) {
        console.log(`\n📱 [SMS BYPASS] To: ${formattedPhone}, Code: ${otp}\n`);
        return true; 
      }
      console.error('❌ Twilio client not initialized');
      return false;
    }

    const message = await client.messages.create({
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
