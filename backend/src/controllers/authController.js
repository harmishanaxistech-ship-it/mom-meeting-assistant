const { generateToken } = require('../middleware/auth');
const env = require('../config/env');
const User = require('../models/User');

/**
 * @desc    Auth user with static/database credentials & get JWT token
 * @route   POST /api/auth/login
 * @access  Public
 */
const login = async (req, res, next) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({
        success: false,
        error: 'Please provide both email and password',
      });
    }

    const normalizedEmail = email.toLowerCase().trim();

    // Check if static credentials match
    if (
      normalizedEmail === env.staticUser.email &&
      password === env.staticUser.password
    ) {
      // Find or upsert static user in DB
      let user = await User.findOne({ email: normalizedEmail });
      if (!user) {
        user = await User.create({
          name: env.staticUser.name,
          email: normalizedEmail,
          password: env.staticUser.password, // will be hashed by User model hook
        });
      }

      const token = generateToken(user._id, user.email);

      return res.status(200).json({
        success: true,
        data: {
          token,
          user: {
            id: user._id,
            name: user.name,
            email: user.email,
          },
        },
      });
    }

    // Otherwise check existing DB users
    const user = await User.findOne({ email: normalizedEmail }).select('+password');
    if (user && (await user.matchPassword(password))) {
      const token = generateToken(user._id, user.email);
      return res.status(200).json({
        success: true,
        data: {
          token,
          user: {
            id: user._id,
            name: user.name,
            email: user.email,
          },
        },
      });
    }

    return res.status(401).json({
      success: false,
      error: 'Invalid email or password',
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Get current logged in user profile
 * @route   GET /api/auth/me
 * @access  Private
 */
const getMe = async (req, res, next) => {
  try {
    res.status(200).json({
      success: true,
      data: {
        user: {
          id: req.user._id,
          name: req.user.name,
          email: req.user.email,
        },
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Log user out / clear session
 * @route   POST /api/auth/logout
 * @access  Private
 */
const logout = async (req, res, next) => {
  try {
    res.status(200).json({
      success: true,
      message: 'Successfully logged out',
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  login,
  getMe,
  logout,
};
