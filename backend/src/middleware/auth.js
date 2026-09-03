const jwt = require('jsonwebtoken');
const env = require('../config/env');
const User = require('../models/User');

const protect = async (req, res, next) => {
  let token;

  if (
    req.headers.authorization &&
    req.headers.authorization.startsWith('Bearer')
  ) {
    try {
      token = req.headers.authorization.split(' ')[1];
      const decoded = jwt.verify(token, env.jwtSecret);

      // Check if user exists in DB, or fallback to mock user for mock mode
      let user = await User.findById(decoded.id).select('-password');
      if (!user && decoded.email === env.staticUser.email) {
        user = {
          _id: decoded.id,
          name: env.staticUser.name,
          email: env.staticUser.email,
        };
      }

      if (!user) {
        return res.status(401).json({
          success: false,
          error: 'User associated with this token not found',
        });
      }

      req.user = user;
      next();
    } catch (error) {
      console.error('[Auth Middleware] Token verification failed:', error.message);
      return res.status(401).json({
        success: false,
        error: 'Not authorized, token invalid or expired',
      });
    }
  } else {
    return res.status(401).json({
      success: false,
      error: 'Not authorized, no bearer token provided',
    });
  }
};

const generateToken = (id, email) => {
  return jwt.sign({ id, email }, env.jwtSecret, {
    expiresIn: env.jwtExpiresIn,
  });
};

module.exports = {
  protect,
  generateToken,
};
