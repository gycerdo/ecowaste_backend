const axios = require('axios');

/**
 * SMS Service - Supports Mambo SMS, Africa's Talking, and Dev Mode Fallback
 * Version: 2.1.0 (Fixed for Mambo SMS v1)
 */

// Configuration
const SMS_CONFIG = {
    // Mambo SMS (Primary)
    mambo: {
        baseURL: process.env.MAMBO_BASE_URL || 'https://mambosms.co.tz',
        token: process.env.MAMBO_TOKEN,
        senderId: process.env.MAMBO_SENDER_ID || 'SIMU VOTE',
        enabled: process.env.ENABLE_MAMBO !== 'false',
        endpoint: '/api/v1/sms/single' // Endpoint sahihi ya Mambo SMS v1
    },

    // Africa's Talking (Fallback)
    africastalking: {
        enabled: process.env.ENABLE_AFRICASTALKING === 'true',
        apiKey: process.env.AT_API_KEY,
        username: process.env.AT_USERNAME || 'sandbox',
        senderId: process.env.AT_SENDER_ID || 'SIMUVOTE'
    },

    // Dev Mode
    devMode: process.env.NODE_ENV !== 'production',
    logOtp: true,

    // Retry settings
    maxRetries: 3,
    retryDelay: 1000, // milliseconds
    timeout: 30000
};

/**
 * Format phone number to local format expected by Mambo SMS (0XXXXXXXXX)
 * @param {string} phone - Raw phone number
 * @returns {string} Formatted phone number starting with 0
 */
function formatPhoneNumber(phone) {
    if (!phone) return null;

    // Ondoa nafasi na alama zote maalum
    let cleaned = phone.toString().trim().replace(/\s/g, '').replace(/[()-]/g, '').replace('+', '');

    // Kama inaanza na kodi ya nchi 255, iondoe na uweke 0
    if (cleaned.startsWith('255')) {
        cleaned = '0' + cleaned.substring(3);
    }
    // Kama haianzi na 0 lakini ina herufi 9 (mfano: 719242796), weka 0 mbele
    else if (!cleaned.startsWith('0') && (cleaned.startsWith('7') || cleaned.startsWith('6') || cleaned.startsWith('default'))) {
        cleaned = '0' + cleaned;
    }

    // Uhakiki wa urefu wa namba ya kawaida ya simu (Tanzania: tarakimu 10)
    if (cleaned.length !== 10 || !cleaned.startsWith('0')) {
        console.warn(`⚠️ Warning: ${phone} formatted as ${cleaned} may not be valid local Tanzanian number`);
    }

    return cleaned;
}

/**
 * Sleep/delay function for retries
 * @param {number} ms - Milliseconds to sleep
 */
const sleep = (ms) => new Promise(resolve => setTimeout(resolve, ms));

/**
 * Send SMS via Mambo API (Primary)
 * @param {string} phone - Recipient phone number
 * @param {string} message - SMS content
 * @returns {Promise<Object>}
 */
async function sendMamboSMS(phone, message) {
    const formattedPhone = formatPhoneNumber(phone);
    const apiUrl = `${SMS_CONFIG.mambo.baseURL}${SMS_CONFIG.mambo.endpoint}`;

    try {
        console.log(`📱 Sending Mambo SMS to: ${formattedPhone} via ${SMS_CONFIG.mambo.endpoint}`);

        // Payload rasmi kulingana na v1 API documentation yao
        const body = {
            sender_id: SMS_CONFIG.mambo.senderId,
            mobile: formattedPhone, // KEY RASMI NI 'mobile'
            message: message
        };

        const response = await axios.post(apiUrl, body, {
            headers: {
                'Authorization': `Bearer ${SMS_CONFIG.mambo.token}`,
                'Content-Type': 'application/json',
                'Accept': 'application/json'
            },
            timeout: SMS_CONFIG.timeout
        });

        // Kuangalia kama imefanikiwa kulingana na majibu ya Mambo API
        if (response.data &&
            (response.data.status === 'success' ||
                response.data.success === true ||
                response.status === 200)) {

            console.log(`✅ Mambo SMS sent successfully`);
            return {
                success: true,
                provider: 'mambo',
                endpoint: SMS_CONFIG.mambo.endpoint,
                messageId: response.data.message_id || response.data.id,
                recipient: formattedPhone
            };
        }

        return { success: false, provider: 'mambo', error: JSON.stringify(response.data) };

    } catch (error) {
        const errorResponse = error.response ? JSON.stringify(error.response.data) : error.message;
        console.log(`⚠️ Mambo SMS execution failed:`, errorResponse);
        return { success: false, provider: 'mambo', error: errorResponse };
    }
}

/**
 * Send SMS via Africa's Talking (Fallback)
 * @param {string} phone - Recipient phone number
 * @param {string} message - SMS content
 * @returns {Promise<Object>}
 */
async function sendAfricasTalkingSMS(phone, message) {
    if (!SMS_CONFIG.africastalking.enabled) {
        return { success: false, provider: 'africastalking', error: 'Not enabled' };
    }

    try {
        const localPhone = formatPhoneNumber(phone);
        // Africa's talking inahitaji 255 mbele badala ya 0
        const atPhone = '255' + localPhone.substring(1);

        const response = await axios.post(
            'https://api.africastalking.com/version1/messaging',
            new URLSearchParams({
                username: SMS_CONFIG.africastalking.username,
                to: atPhone,
                from: SMS_CONFIG.africastalking.senderId,
                message: message
            }),
            {
                headers: {
                    'apiKey': SMS_CONFIG.africastalking.apiKey,
                    'Content-Type': 'application/x-www-form-urlencoded',
                    'Accept': 'application/json'
                },
                timeout: SMS_CONFIG.timeout
            }
        );

        if (response.data && response.data.SMSMessageData) {
            const result = response.data.SMSMessageData;
            if (result.Recipients && result.Recipients[0].status === 'Success') {
                console.log('✅ Africa\'s Talking SMS sent');
                return {
                    success: true,
                    provider: 'africastalking',
                    messageId: result.Recipients[0].messageId,
                    recipient: atPhone
                };
            }
        }

        return { success: false, provider: 'africastalking', error: 'API returned error' };
    } catch (error) {
        console.error('❌ Africa\'s Talking error:', error.message);
        return { success: false, provider: 'africastalking', error: error.message };
    }
}

/**
 * Dev Mode Fallback - Log SMS to console
 * @param {string} phone - Recipient phone number
 * @param {string} message - SMS content
 * @returns {Promise<Object>}
 */
async function sendDevModeSMS(phone, message) {
    const formattedPhone = formatPhoneNumber(phone);

    console.log('\n' + '═'.repeat(60));
    console.log('📱 DEV MODE SMS (Not actually sent)');
    console.log('═'.repeat(60));
    console.log(`📞 To: ${phone} -> ${formattedPhone}`);
    console.log(`💬 Message: ${message}`);
    console.log('═'.repeat(60) + '\n');

    const otpMatch = message.match(/\b\d{6}\b/);
    if (otpMatch && SMS_CONFIG.logOtp) {
        console.log(`🔐 🔐 🔐 OTP CODE: ${otpMatch[0]} 🔐 🔐 🔐\n`);
    }

    return {
        success: true,
        provider: 'dev-mode',
        devMode: true,
        recipient: formattedPhone,
        message: message,
        otp: otpMatch ? otpMatch[0] : null
    };
}

/**
 * Main send SMS function with retry logic and provider failover
 * @param {string} phone - Recipient phone number
 * @param {string} message - SMS content
 * @param {Object} options - Additional options
 * @returns {Promise<Object>}
 */
async function sendSMS(phone, message, options = {}) {
    if (!phone || !message) {
        throw new Error('Missing required parameters: phone or message');
    }

    if (SMS_CONFIG.devMode && options.devMode !== false) {
        return await sendDevModeSMS(phone, message);
    }

    let lastError = null;

    // Try Mambo first (primary provider)
    if (SMS_CONFIG.mambo.enabled && SMS_CONFIG.mambo.token) {
        for (let attempt = 1; attempt <= SMS_CONFIG.maxRetries; attempt++) {
            const result = await sendMamboSMS(phone, message);
            if (result.success) return result;
            lastError = result.error;
            if (attempt < SMS_CONFIG.maxRetries) {
                await sleep(SMS_CONFIG.retryDelay * attempt);
            }
        }
    }

    // Fallback to Africa's Talking if Mambo fails
    if (SMS_CONFIG.africastalking.enabled) {
        const result = await sendAfricasTalkingSMS(phone, message);
        if (result.success) return result;
        lastError = result.error;
    }

    if (SMS_CONFIG.devMode) {
        console.log(`⚠️ All SMS providers failed, falling back to dev mode`);
        return await sendDevModeSMS(phone, message);
    }

    return {
        success: false,
        error: `All SMS providers failed. Last error: ${lastError}`,
        recipient: formatPhoneNumber(phone)
    };
}

/**
 * Send OTP verification code via SMS
 */
async function sendOtpSMS(phone, otp, name = 'Customer') {
    const expiresIn = 10;
    const message = `🔐 ${name}, your EcoWaste verification code is: ${otp}. Valid for ${expiresIn} minutes. NEVER share this code with anyone. EcoWaste Team.`;

    const result = await sendSMS(phone, message);

    if (result.provider === 'dev-mode' && result.otp) {
        result.devOtp = result.otp;
    }

    return result;
}

/**
 * Send welcome message via SMS
 */
async function sendWelcomeSMS(phone, name) {
    const message = `🌿 Welcome ${name} to EcoWaste! 🌍 Book waste collection, find recycling centers & earn points. Together for a cleaner Tanzania! Download app: https://ecowaste.app`;
    return await sendSMS(phone, message);
}

/**
 * Send booking confirmation via SMS
 */
async function sendBookingSMS(phone, name, bookingDetails) {
    const message = `✅ ${name}, your booking at ${bookingDetails.center_name} on ${bookingDetails.booking_date} at ${bookingDetails.time_slot} is confirmed. Booking ID: #${bookingDetails.id}. Show this SMS at the center. Thank you for recycling! 🌍 EcoWaste`;
    return await sendSMS(phone, message);
}

/**
 * Send booking reminder via SMS (24 hours before)
 */
async function sendBookingReminderSMS(phone, name, bookingDetails) {
    const message = `⏰ Reminder ${name}! Your waste collection at ${bookingDetails.center_name} is tomorrow (${bookingDetails.booking_date}) at ${bookingDetails.time_slot}. Please arrive on time. EcoWaste 🌿`;
    return await sendSMS(phone, message);
}

/**
 * Send booking cancellation notification via SMS
 */
async function sendCancellationSMS(phone, name, bookingDetails, reason = '') {
    const message = `⚠️ ${name}, your booking at ${bookingDetails.center_name} on ${bookingDetails.booking_date} has been CANCELLED. Reason: ${reason || 'Not specified'}. To rebook, use the app. EcoWaste`;
    return await sendSMS(phone, message);
}

/**
 * Send points earned notification via SMS
 */
async function sendPointsEarnedSMS(phone, name, points, activity) {
    const message = `🎉 Congratulations ${name}! You've earned ${points} points for ${activity}. Keep recycling and earn more rewards! EcoWaste 🌟`;
    return await sendSMS(phone, message);
}

/**
 * Send bulk SMS to multiple recipients
 */
async function sendBulkSMS(phones, message, delayMs = 500) {
    const results = [];

    for (let i = 0; i < phones.length; i++) {
        const phone = phones[i];
        console.log(`📱 Sending bulk SMS ${i + 1}/${phones.length} to ${phone}`);

        const result = await sendSMS(phone, message);
        results.push({ phone, ...result });

        if (i < phones.length - 1 && delayMs > 0) {
            await sleep(delayMs);
        }
    }

    const successful = results.filter(r => r.success).length;
    console.log(`📊 Bulk SMS complete: ${successful}/${phones.length} successful`);

    return results;
}

/**
 * Check SMS balance
 */
async function checkSMSBalance() {
    try {
        const response = await axios.get(
            `${SMS_CONFIG.mambo.baseURL}/api/balance`,
            {
                headers: {
                    'Authorization': `Bearer ${SMS_CONFIG.mambo.token}`,
                    'Accept': 'application/json'
                },
                timeout: SMS_CONFIG.timeout
            }
        );

        if (response.data && response.data.balance !== undefined) {
            return {
                success: true,
                provider: 'mambo',
                balance: response.data.balance,
                currency: response.data.currency || 'TZS'
            };
        }
    } catch (error) {
        console.log('⚠️ Could not fetch Mambo balance');
    }

    return {
        success: false,
        error: 'Unable to fetch SMS balance'
    };
}

/**
 * Test SMS configuration
 */
function getSMSStatus() {
    return {
        devMode: SMS_CONFIG.devMode,
        providers: {
            mambo: {
                enabled: SMS_CONFIG.mambo.enabled,
                configured: !!SMS_CONFIG.mambo.token,
                baseURL: SMS_CONFIG.mambo.baseURL,
                senderId: SMS_CONFIG.mambo.senderId
            },
            africastalking: {
                enabled: SMS_CONFIG.africastalking.enabled,
                configured: !!SMS_CONFIG.africastalking.apiKey,
                username: SMS_CONFIG.africastalking.username
            }
        },
        retrySettings: {
            maxRetries: SMS_CONFIG.maxRetries,
            retryDelay: SMS_CONFIG.retryDelay,
            timeout: SMS_CONFIG.timeout
        }
    };
}

module.exports = {
    sendSMS,
    sendOtpSMS,
    sendWelcomeSMS,
    sendBookingSMS,
    sendBookingReminderSMS,
    sendCancellationSMS,
    sendPointsEarnedSMS,
    sendBulkSMS,
    formatPhoneNumber,
    checkSMSBalance,
    getSMSStatus,
    sendMamboSMS,
    sendAfricasTalkingSMS,
    sendDevModeSMS
};