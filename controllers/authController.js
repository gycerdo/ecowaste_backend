// -- 1. Register User ---------------------------------------------------------
exports.register = async (req, res) => {
  try {
    res.status(201).json({ success: true, message: "User registered successfully" });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// -- 2. Login User ------------------------------------------------------------
exports.login = async (req, res) => {
  try {
    res.json({ success: true, message: "Logged in successfully", token: "dummy-token" });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// -- 3. Get User Profile ------------------------------------------------------
exports.getProfile = async (req, res) => {
  try {
    res.json({ success: true, message: "Fetched profile successfully", user: req.user });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};
