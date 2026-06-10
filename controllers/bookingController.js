// ── 1. Get all waste collection centers ───────────────────────────────────────
exports.getCenters = async (req, res) => {
    try {
        // Your actual DB query goes here
        res.json({ success: true, message: "Fetched collection centers successfully", data: [] });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
};

// ── 2. Create a new waste collection booking ──────────────────────────────────
exports.createBooking = async (req, res) => {
    try {
        res.status(201).json({ success: true, message: "Booking created successfully" });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
};

// ── 3. Get all bookings for the logged-in user ───────────────────────────────
exports.getMyBookings = async (req, res) => {
    try {
        res.json({ success: true, message: "Fetched user bookings successfully", data: [] });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
};

// ── 4. Get a specific booking by ID ──────────────────────────────────────────
exports.getBookingById = async (req, res) => {
    try {
        const { id } = req.params;
        res.json({ success: true, message: `Fetched booking ${id} successfully` });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
};

// ── 5. Cancel a booking ──────────────────────────────────────────────────────
exports.cancelBooking = async (req, res) => {
    try {
        const { id } = req.params;
        res.json({ success: true, message: `Booking ${id} cancelled successfully` });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
};

// ── 6. Mark a booking as completed ───────────────────────────────────────────
exports.completeBooking = async (req, res) => {
    try {
        const { id } = req.params;
        res.json({ success: true, message: `Booking ${id} marked as complete` });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
};