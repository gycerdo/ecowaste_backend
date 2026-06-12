const express = require('express');
const cors = require('cors');
const axios = require('axios');
const nodemailer = require('nodemailer');
require('dotenv').config();

const app = express();
app.use(cors());
app.use(express.json());

// FIXED: Inaruhusu 06, 07, 2556, 2557 na kuzisafisha vizuri
function _normalizePhone(phone) {
  if (!phone) return '';
  
  // Ondoa herufi zote zisizo namba (kama +, nafasi, au mabano)
  let cleaned = phone.toString().replace(/\D/g, '');
  
  // Kama inaanza na 06 au 07 (Inafanya kazi kwa 06xxxxxxx na 07xxxxxxx)
  if (cleaned.startsWith('0') && (cleaned.startsWith('06') || cleaned.startsWith('07'))) {
    cleaned = '255' + cleaned.substring(1);
  }
  
  // Kama mtumiaji aliandika namba 9 tu bila 0 mwanzo (mfano: 6xxxxxxx au 7xxxxxxx)
  if ((cleaned.startsWith('6') || cleaned.startsWith('7')) && cleaned.length === 9) {
    cleaned = '255' + cleaned;
  }
  
  return cleaned;
}

async function sendSMS(phone, message) {
  const to = _normalizePhone(phone);
  const token = process.env.MAMBO_TOKEN || process.env.MAMBOSMS_TOKEN;
  const senderId = process.env.MAMBO_SENDER_ID || process.env.MAMBOSMS_SENDER || 'EcoWaste';
  
  const baseUrl = 'https://api.mambosms.co.tz/v1/send';
  const finalizedText = message || 'Kodi yako ya uhakiki ya EcoWaste ni 1234';

  let smsResult = { success: false };
  let emailResult = { success: false, error: 'Not attempted' };

  if (!to || to.length !== 12 || !to.startsWith('255')) {
    console.error(`[SMS] ? Namba ya simu haina muundo sahihi wa Tanzania: ${phone}`);
    return { success: false, error: 'Invalid Tanzania phone number format' };
  }

  // 1. MAMBO SMS INTEGRATION
  if (token) {
    console.log(`[SMS] Inatuma kwenda Mambo SMS kwa namba: ${to}`);
    try {
      const resp = await axios.post(
        baseUrl,
        { 
          phone: to, 
          sender_id: senderId, 
          message: finalizedText 
        },
        {
          headers: {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json'
          },
          timeout: 20000
        }
      );
      smsResult = { success: true, mambo_response: resp.data };
    } catch (err) {
      smsResult = { success: false, error: err.response ? JSON.stringify(err.response.data) : err.message };
    }
  } else {
    console.warn('[SMS] ?? MAMBO_TOKEN haipo kwenye Render');
    smsResult = { success: false, error: 'MAMBO_TOKEN not configured' };
  }

  // 2. NODEMAILER INTEGRATION
  try {
    const transporter = nodemailer.createTransport({
      host: process.env.SMTP_HOST || 'smtp.hostinger.com',
      port: parseInt(process.env.SMTP_PORT || '587', 10),
      secure: false, 
      auth: {
        user: process.env.SMTP_USER || process.env.SMTP_FROM || 'support@simuvote.com',
        pass: process.env.SMTP_PASS
      },
      tls: {
        rejectUnauthorized: false,
        minVersion: 'TLSv1.2'
      },
      family: 4,
      connectionTimeout: 20000,
      greetingTimeout: 15000
    });

    const senderName = process.env.SMTP_FROM_NAME || 'EcoWaste Support';
    const senderEmail = process.env.SMTP_USER || process.env.SMTP_FROM || 'support@simuvote.com';

    const info = await transporter.sendMail({
      from: `"${senderName}" <${senderEmail}>`,
      to: 'gycerdo27@gmail.com',
      subject: 'EcoWaste Verification OTP',
      text: finalizedText,
      html: `
        <div style="font-family: sans-serif; padding: 20px; border: 1px solid #e0e0e0; border-radius: 8px; max-width: 500px;">
          <h2 style="color: #4CAF50; border-bottom: 2px solid #4CAF50; padding-bottom: 10px;">EcoWaste System</h2>
          <p style="font-size: 16px; color: #333; line-height: 1.5;">${finalizedText}</p>
          <hr style="border: none; border-top: 1px solid #eee; margin-top: 20px;" />
          <footer style="font-size: 12px; color: #777;">Ujumbe huu ni wa kiotomatiki kwa usalama wa akaunti yako.</footer>
        </div>
      `
    });
    emailResult = { success: true, messageId: info.messageId };
  } catch (mailErr) {
    emailResult = { success: false, error: mailErr.message };
  }

  const overallSuccess = smsResult.success || emailResult.success;

  return {
    success: overallSuccess,
    message: overallSuccess ? "OTP imetumwa kikamilifu" : "Imeshindwa kutuma huduma zote mbili",
    delivered: overallSuccess,
    results: {
      sms: smsResult,
      email: emailResult
    }
  };
}

app.post('/api/auth/send-otp', async (req, res) => {
  const { phone } = req.body;
  if (!phone) {
    return res.status(400).json({ success: false, message: "Namba ya simu inahitajika" });
  }

  const generatedOTP = Math.floor(100000 + Math.random() * 900000).toString();
  const smsMessage = `Dear User, your EcoWaste verification code is: ${generatedOTP}. Valid for 10 minutes.`;

  const notificationReport = await sendSMS(phone, smsMessage);

  if (!notificationReport.success) {
    return res.status(500).json(notificationReport);
  }

  return res.status(200).json(notificationReport);
});

app.get('/', (req, res) => {
  res.send('? EcoWaste API is running smoothly on Render!');
});

const PORT = process.env.PORT || 10000;
app.listen(PORT, () => {
  console.log(`[Seva] Backend imewaka vizuri kwenye port ${PORT}`);
});

module.exports = app;