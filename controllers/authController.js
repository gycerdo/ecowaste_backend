const db = require('../config/db');
// Kama unatumia bcrypt kufanya hash ya password, iache hii. Kama unahifadhi plain text, unaweza kuifuta.
const bcrypt = require('bcrypt');

// ==========================================
// 1. LOGIC YA USAJILI (REGISTER)
// ==========================================
exports.register = async (req, res) => {
    const { name, username, email, phone, password, vehicle_type } = req.body;

    // Uhakiki wa data za msingi zilizotumwa kutoka Flutter
    if (!name || !username || !email || !phone || !password) {
        return res.status(400).json({
            success: false,
            message: "Tafadhali jaza sifa zote muhimu (name, username, email, phone, password)"
        });
    }

    try {
        // 1. Angalia kama mtumiaji tayari yupo kwenye database
        const userExists = await db.query(
            'SELECT * FROM users WHERE email = $1 OR phone = $2 OR username = $3',
            [email, phone, username]
        );

        if (userExists.rows.length > 0) {
            return res.status(400).json({
                success: false,
                message: "Mtumiaji mwenye Username, Email au Namba hii ya simu tayari yupo!"
            });
        }

        // 2. Kufanya hash ya password (Usalama wa mtumiaji)
        const saltRounds = 10;
        const hashedPassword = await bcrypt.hash(password, saltRounds);

        // 3. Tengeneza tarakimu 6 za OTP
        const otpToken = Math.floor(100000 + Math.random() * 900000).toString();
        const otpExpires = new Date(Date.now() + 10 * 60 * 1000); // Dakika 10 kutoka sasa

        // 4. Iniza Mtumiaji kwenye table ya "users" (Inajumuisha vehicle_type yenye default 'NONE')
        const newUserQuery = `
            INSERT INTO users (name, username, email, phone, password, vehicle_type, otp_token, otp_expires)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
            RETURNING id, name, username, email, phone, vehicle_type
        `;
        const newUserValues = [name, username, email, phone, hashedPassword, vehicle_type || 'NONE', otpToken, otpExpires];
        const userResult = await db.query(newUserQuery, newUserValues);

        // 5. Iniza OTP pia kwenye table maalum ya "otp_codes" kwa usalama wa baadae
        const otpQuery = `
            INSERT INTO otp_codes (phone, code, expires_at, used)
            VALUES ($1, $2, $3, false)
        `;
        await db.query(otpQuery, [phone, otpToken, otpExpires]);

        // 6. KUTUMA OTP (Hapa unaunganisha na smsService na emailService zako zilizopo)
        const messageBody = `Karibu EcoWaste! Code yako ya uhakiki (OTP) ni: ${otpToken}. Itasimama baada ya dakika 10.`;

        try {
            // Unafungua mifumo yako ya sms na email hapa chini
            // const { sendSMS } = require('../services/smsService');
            // const { sendEmail } = require('../services/emailService');
            // await sendSMS(phone, messageBody);
            // await sendEmail(email, "Uhakiki wa Akaunti - EcoWaste", messageBody);
            console.log(`[OTP SENT] Token ya ${username} ni: ${otpToken}`);
        } catch (sendError) {
            console.error("Mifumo ya kutuma ujumbe ina changamoto lakini usajili umekamilika:", sendError);
        }

        return res.status(201).json({
            success: true,
            message: "Usajili umefanikiwa! OTP imesafirishwa kwenye SMS na Email yako.",
            user: userResult.rows[0]
        });

    } catch (error) {
        console.error("Error wakati wa kusajili:", error);
        return res.status(500).json({
            success: false,
            message: "Hitilafu imetokea kwenye server wakati wa usajili.",
            error: error.message
        });
    }
};

// ==========================================
// 2. LOGIC YA KUINGIA (LOGIN)
// ==========================================
exports.login = async (req, res) => {
    const { login_identifier, password } = req.body; // login_identifier inaweza kuwa email, username au phone

    if (!login_identifier || !password) {
        return res.status(400).json({
            success: false,
            message: "Tafadhali jaza barua pepe/namba ya simu na password."
        });
    }

    try {
        // 1. Tafuta mtumiaji kwa kutumia Email, Username au Namba ya Simu
        const userQuery = `
            SELECT * FROM users 
            WHERE email = $1 OR username = $1 OR phone = $1
        `;
        const result = await db.query(userQuery, [login_identifier.trim()]);

        if (result.rows.length === 0) {
            return res.status(404).json({
                success: false,
                message: "Mtumiaji hapatikani! Tafadhali kagua taarifa zako."
            });
        }

        const user = result.rows[0];

        // 2. Uhakiki wa password iliyohifadhiwa (bcrypt check)
        const isPasswordMatch = await bcrypt.compare(password, user.password);
        if (!isPasswordMatch) {
            return res.status(401).json({
                success: false,
                message: "Nenosiri (Password) si sahihi!"
            });
        }

        // 3. Jibu la mafanikio kwenda Flutter (Unaweza kuongeza JWT token hapa kama unatumia)
        return res.status(200).json({
            success: true,
            message: "Umeingia kwenye mfumo kwa mafanikio!",
            user: {
                id: user.id,
                name: user.name,
                username: user.username,
                email: user.email,
                phone: user.phone,
                vehicle_type: user.vehicle_type
            }
        });

    } catch (error) {
        console.error("Error wakati wa ku-login:", error);
        return res.status(500).json({
            success: false,
            message: "Hitilafu imetokea kwenye server wakati wa kuingia.",
            error: error.message
        });
    }
};