const { sendEmail, sendWelcomeEmail, sendOtpEmail, sendBookingConfirmation } = require('./emailService');
const { sendSMS, sendOtpSMS, sendWelcomeSMS, sendBookingSMS, sendCancellationSMS, sendPointsEarnedSMS } = require('./smsService');

/**
 * Send OTP via specific channel
 * @param {string} contact - Email address or phone number
 * @param {string} otp - 6-digit OTP code
 * @param {string} name - User's name
 * @param {string} channel - 'email' or 'sms'
 * @returns {Promise<Object>} Result with success status and channel used
 */
async function sendOTP(contact, otp, name = 'User', channel = 'email') {
    try {
        if (channel === 'email') {
            const result = await sendOtpEmail(contact, otp, name);
            return {
                success: result.success,
                channelUsed: 'email',
                messageId: result.messageId,
                error: result.error
            };
        } else if (channel === 'sms') {
            const result = await sendOtpSMS(contact, otp, name);
            return {
                success: result.success,
                channelUsed: 'sms',
                messageId: result.messageId,
                devOtp: result.devOtp, // For development
                error: result.error
            };
        } else {
            return { success: false, error: 'Invalid channel. Use "email" or "sms"' };
        }
    } catch (error) {
        console.error('sendOTP error:', error);
        return { success: false, error: error.message };
    }
}

/**
 * Send welcome notification via all available channels
 * @param {Object} options - Notification options
 * @param {string} options.email - User's email
 * @param {string} options.phone - User's phone
 * @param {string} options.name - User's full name
 * @returns {Promise<Object>} Results for each channel
 */
async function sendWelcomeNotification({ email = null, phone = null, name = 'User' }) {
    const results = { email: null, sms: null, success: false };

    console.log(`📢 Sending welcome notification to ${name} (Email: ${email || 'N/A'}, Phone: ${phone || 'N/A'})`);

    try {
        // Send email if provided
        if (email) {
            results.email = await sendWelcomeEmail(email, name);
            console.log(`📧 Welcome email ${results.email.success ? 'sent' : 'failed'} to ${email}`);
        }

        // Send SMS if provided
        if (phone) {
            results.sms = await sendWelcomeSMS(phone, name);
            console.log(`📱 Welcome SMS ${results.sms.success ? 'sent' : 'failed'} to ${phone}`);
        }

        results.success = results.email?.success || results.sms?.success || false;
        return results;
    } catch (error) {
        console.error('sendWelcomeNotification error:', error);
        results.success = false;
        results.error = error.message;
        return results;
    }
}

/**
 * Send booking confirmation notification
 * @param {Object} user - User object with email, phone, name
 * @param {Object} bookingDetails - Booking details
 * @returns {Promise<Object>} Results for each channel
 */
async function sendBookingNotification(user, bookingDetails) {
    const results = { email: null, sms: null, success: false };

    console.log(`📢 Sending booking confirmation to ${user.name || user.full_name}`);

    try {
        // Send email if provided
        if (user.email) {
            results.email = await sendBookingConfirmation(user.email, user.name || user.full_name, bookingDetails);
            console.log(`📧 Booking email ${results.email.success ? 'sent' : 'failed'} to ${user.email}`);
        }

        // Send SMS if provided
        if (user.phone) {
            results.sms = await sendBookingSMS(user.phone, user.name || user.full_name, bookingDetails);
            console.log(`📱 Booking SMS ${results.sms.success ? 'sent' : 'failed'} to ${user.phone}`);
        }

        results.success = results.email?.success || results.sms?.success || false;
        return results;
    } catch (error) {
        console.error('sendBookingNotification error:', error);
        results.success = false;
        results.error = error.message;
        return results;
    }
}

/**
 * Send booking reminder notification (24 hours before)
 * @param {Object} user - User object with phone, name
 * @param {Object} bookingDetails - Booking details
 * @returns {Promise<Object>} Result
 */
async function sendBookingReminderNotification(user, bookingDetails) {
    try {
        if (!user.phone) {
            return { success: false, error: 'No phone number provided' };
        }

        const result = await sendSMS(
            user.phone,
            `⏰ Reminder ${user.name || user.full_name}! Your waste collection at ${bookingDetails.center_name} is tomorrow (${bookingDetails.booking_date}) at ${bookingDetails.time_slot}. Please arrive on time. EcoWaste 🌿`
        );

        return result;
    } catch (error) {
        console.error('sendBookingReminderNotification error:', error);
        return { success: false, error: error.message };
    }
}

/**
 * Send booking cancellation notification
 * @param {Object} user - User object with email, phone, name
 * @param {Object} bookingDetails - Booking details with center_name, booking_date
 * @param {string} reason - Cancellation reason
 * @returns {Promise<Object>} Results for each channel
 */
async function sendCancellationNotification(user, bookingDetails, reason = '') {
    const results = { email: null, sms: null, success: false };

    console.log(`📢 Sending cancellation notification to ${user.name || user.full_name}`);

    try {
        // Send SMS if provided
        if (user.phone) {
            results.sms = await sendCancellationSMS(user.phone, user.name || user.full_name, bookingDetails, reason);
            console.log(`📱 Cancellation SMS ${results.sms.success ? 'sent' : 'failed'} to ${user.phone}`);
        }

        // Send email if provided
        if (user.email) {
            const subject = `Booking Cancelled - ${bookingDetails.center_name}`;
            const text = `Dear ${user.name || user.full_name},\n\nYour booking at ${bookingDetails.center_name} on ${bookingDetails.booking_date} has been cancelled.\n\nReason: ${reason || 'Not specified'}\n\nTo make a new booking, please use the app.\n\nEcoWaste Team`;
            results.email = await sendEmail(user.email, subject, text);
            console.log(`📧 Cancellation email ${results.email.success ? 'sent' : 'failed'} to ${user.email}`);
        }

        results.success = results.email?.success || results.sms?.success || false;
        return results;
    } catch (error) {
        console.error('sendCancellationNotification error:', error);
        results.success = false;
        results.error = error.message;
        return results;
    }
}

/**
 * Send points earned notification
 * @param {Object} user - User object with email, phone, name
 * @param {number} points - Points earned
 * @param {string} activity - Activity description
 * @param {number} totalPoints - Total points after earning
 * @returns {Promise<Object>} Results for each channel
 */
async function sendPointsEarnedNotification(user, points, activity, totalPoints = null) {
    const results = { email: null, sms: null, success: false };

    console.log(`📢 Sending points notification to ${user.name || user.full_name}: +${points} points`);

    try {
        // Prefer SMS for points notifications (instant gratification)
        if (user.phone) {
            results.sms = await sendPointsEarnedSMS(user.phone, user.name || user.full_name, points, activity);
            console.log(`📱 Points SMS ${results.sms.success ? 'sent' : 'failed'} to ${user.phone}`);
        }

        // Send email as backup or if no phone
        if (user.email && (!user.phone || !results.sms?.success)) {
            const subject = `🎉 You earned ${points} points!`;
            const text = `Dear ${user.name || user.full_name},\n\nCongratulations! You've earned ${points} points for ${activity}.\n\n${totalPoints ? `Total points: ${totalPoints}` : ''}\n\nKeep up the great work in protecting our environment!\n\nEcoWaste Team`;
            results.email = await sendEmail(user.email, subject, text);
            console.log(`📧 Points email ${results.email.success ? 'sent' : 'failed'} to ${user.email}`);
        }

        results.success = results.email?.success || results.sms?.success || false;
        return results;
    } catch (error) {
        console.error('sendPointsEarnedNotification error:', error);
        results.success = false;
        results.error = error.message;
        return results;
    }
}

/**
 * Unified notification dispatcher
 * @param {Object} options - Notification options
 * @param {string} options.email - Recipient email
 * @param {string} options.phone - Recipient phone
 * @param {string} options.name - Recipient name
 * @param {string} options.type - Notification type (otp, welcome, booking, booking_reminder, booking_cancelled, points_earned, password_reset)
 * @param {Object} options.data - Additional data specific to notification type
 * @param {string} options.otp - OTP code (for type='otp')
 * @param {string} options.channel - Preferred channel (for type='otp')
 * @returns {Promise<Object>} Results
 */
async function sendNotification({ email = null, phone = null, name = 'User', type = 'welcome', data = {}, otp = null, channel = null }) {
    const results = { email: null, sms: null, success: false, channelUsed: null };

    console.log(`📢 Sending ${type} notification to ${name} (Email: ${email || 'N/A'}, Phone: ${phone || 'N/A'})`);

    try {
        switch (type) {
            case 'otp':
                if (!otp) throw new Error('OTP code is required for OTP notifications');

                if (channel === 'email' && email) {
                    results.email = await sendOtpEmail(email, otp, name);
                    results.channelUsed = 'email';
                } else if (channel === 'sms' && phone) {
                    results.sms = await sendOtpSMS(phone, otp, name);
                    results.channelUsed = 'sms';
                    if (results.sms.devOtp) results.devOtp = results.sms.devOtp;
                } else if (email && phone) {
                    // Try both, prefer email
                    results.email = await sendOtpEmail(email, otp, name);
                    if (!results.email.success) {
                        results.sms = await sendOtpSMS(phone, otp, name);
                        results.channelUsed = results.sms.success ? 'sms-fallback' : 'none';
                    } else {
                        results.channelUsed = 'email';
                    }
                } else if (email) {
                    results.email = await sendOtpEmail(email, otp, name);
                    results.channelUsed = 'email';
                } else if (phone) {
                    results.sms = await sendOtpSMS(phone, otp, name);
                    results.channelUsed = 'sms';
                    if (results.sms.devOtp) results.devOtp = results.sms.devOtp;
                } else {
                    throw new Error('No email or phone provided');
                }
                break;

            case 'welcome':
                if (email) results.email = await sendWelcomeEmail(email, name);
                if (phone) results.sms = await sendWelcomeSMS(phone, name);
                results.channelUsed = results.email?.success ? 'email' : (results.sms?.success ? 'sms' : 'none');
                break;

            case 'booking':
                if (!data.center_name || !data.booking_date || !data.time_slot) {
                    throw new Error('Missing booking data: center_name, booking_date, time_slot');
                }
                if (email) results.email = await sendBookingConfirmation(email, name, data);
                if (phone) results.sms = await sendBookingSMS(phone, name, data);
                results.channelUsed = results.email?.success ? 'email' : (results.sms?.success ? 'sms' : 'none');
                break;

            case 'booking_reminder':
                if (!data.center_name || !data.booking_date || !data.time_slot) {
                    throw new Error('Missing booking data');
                }
                if (phone) {
                    results.sms = await sendSMS(phone, `⏰ Reminder ${name}! Your waste collection at ${data.center_name} is tomorrow (${data.booking_date}) at ${data.time_slot}. Please arrive on time. EcoWaste 🌿`);
                    results.channelUsed = 'sms';
                }
                break;

            case 'booking_cancelled':
                if (!data.center_name || !data.booking_date) {
                    throw new Error('Missing booking data');
                }
                if (email) {
                    const subject = `Booking Cancelled - ${data.center_name}`;
                    const text = `Dear ${name},\n\nYour booking at ${data.center_name} on ${data.booking_date} has been cancelled.\n\nReason: ${data.reason || 'Not specified'}\n\nTo make a new booking, please use the app.\n\nEcoWaste Team`;
                    results.email = await sendEmail(email, subject, text);
                }
                if (phone) {
                    results.sms = await sendCancellationSMS(phone, name, data, data.reason);
                }
                results.channelUsed = results.email?.success ? 'email' : (results.sms?.success ? 'sms' : 'none');
                break;

            case 'points_earned':
                if (!data.points || !data.activity) {
                    throw new Error('Missing points or activity data');
                }
                if (phone) {
                    results.sms = await sendPointsEarnedSMS(phone, name, data.points, data.activity);
                    results.channelUsed = 'sms';
                }
                if (email && (!phone || !results.sms?.success)) {
                    const subject = `🎉 You earned ${data.points} points!`;
                    const text = `Dear ${name},\n\nCongratulations! You've earned ${data.points} points for ${data.activity}.\n\n${data.totalPoints ? `Total points: ${data.totalPoints}` : ''}\n\nKeep up the great work!\n\nEcoWaste Team`;
                    results.email = await sendEmail(email, subject, text);
                    results.channelUsed = results.email?.success ? 'email-fallback' : results.channelUsed;
                }
                break;

            case 'password_reset':
                if (!data.resetToken) throw new Error('Reset token required');
                if (email) {
                    const resetLink = `https://simuvote.com/reset-password?token=${data.resetToken}`;
                    const subject = '🔒 Password Reset Request - EcoWaste';
                    const text = `Dear ${name},\n\nClick the link below to reset your password:\n${resetLink}\n\nThis link expires in 1 hour.\n\nIf you didn't request this, please ignore this email.\n\nEcoWaste Team`;
                    results.email = await sendEmail(email, subject, text);
                    results.channelUsed = 'email';
                }
                break;

            default:
                throw new Error(`Unknown notification type: ${type}`);
        }

        results.success = results.email?.success || results.sms?.success || false;

        if (results.success) {
            console.log(`✅ ${type} notification sent via ${results.channelUsed}`);
        } else {
            console.log(`⚠️ Failed to send ${type} notification to ${name}`);
        }

        return results;
    } catch (error) {
        console.error(`❌ Notification error (${type}):`, error.message);
        results.success = false;
        results.error = error.message;
        return results;
    }
}

module.exports = {
    // Main unified function
    sendNotification,

    // Specific notification functions
    sendOTP,
    sendWelcomeNotification,
    sendBookingNotification,
    sendBookingReminderNotification,
    sendCancellationNotification,
    sendPointsEarnedNotification,

    // Direct service access (for advanced use)
    emailService: { sendEmail, sendWelcomeEmail, sendOtpEmail, sendBookingConfirmation },
    smsService: { sendSMS, sendOtpSMS, sendWelcomeSMS, sendBookingSMS, sendCancellationSMS, sendPointsEarnedSMS }
};