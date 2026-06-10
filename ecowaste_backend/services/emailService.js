const nodemailer = require('nodemailer');

const transporter = nodemailer.createTransport({
    host: process.env.SMTP_HOST || 'smtp.hostinger.com',
    port: parseInt(process.env.SMTP_PORT) || 587,
    secure: false,
    auth: {
        user: process.env.SMTP_USER || 'support@simuvote.com',
        pass: process.env.SMTP_PASS,
    },
    tls: {
        rejectUnauthorized: false
    }
});

async function sendEmail(to, subject, text, html = null) {
    try {
        const mailOptions = {
            from: `"${process.env.SMTP_FROM_NAME || 'EcoWaste Support'}" <${process.env.SMTP_FROM || 'support@simuvote.com'}>`,
            to,
            subject,
            text,
        };
        if (html) mailOptions.html = html;

        const info = await transporter.sendMail(mailOptions);
        console.log(`📧 Email sent: ${info.messageId}`);
        return { success: true, messageId: info.messageId };
    } catch (error) {
        console.error('Email error:', error);
        return { success: false, error: error.message };
    }
}

async function sendOtpEmail(to, otp, name) {
    const subject = 'Your EcoWaste Verification Code';
    const text = `Dear ${name},\n\nYour verification code is: ${otp}\n\nThis code expires in 10 minutes.\n\nDo not share this code with anyone.\n\nThank you for using EcoWaste!`;
    return await sendEmail(to, subject, text);
}

async function sendWelcomeEmail(to, name) {
    const subject = 'Welcome to EcoWaste! 🌿';
    const html = `
        <div style="font-family: Arial, sans-serif; max-width: 600px;">
            <h2 style="color: #2E7D32;">Welcome ${name}!</h2>
            <p>Thank you for joining EcoWaste - your partner in sustainable waste management.</p>
            <p>Start making a difference today!</p>
            <br>
            <p>Best regards,<br>EcoWaste Team</p>
        </div>
    `;
    return await sendEmail(to, subject, null, html);
}

async function sendBookingConfirmation(to, name, bookingDetails) {
    const subject = 'Booking Confirmation - EcoWaste';
    const html = `
        <div style="font-family: Arial, sans-serif;">
            <h2 style="color: #2E7D32;">Booking Confirmed!</h2>
            <p>Dear ${name},</p>
            <p>Your booking has been confirmed:</p>
            <ul>
                <li>Center: ${bookingDetails.center_name}</li>
                <li>Date: ${bookingDetails.booking_date}</li>
                <li>Time: ${bookingDetails.time_slot}</li>
                <li>Waste: ${bookingDetails.waste_types?.join(', ')}</li>
            </ul>
            <p>Thank you for recycling! 🌍</p>
        </div>
    `;
    return await sendEmail(to, subject, null, html);
}

module.exports = { sendEmail, sendOtpEmail, sendWelcomeEmail, sendBookingConfirmation };