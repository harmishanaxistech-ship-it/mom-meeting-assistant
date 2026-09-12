const express = require('express');
const { getCompanyByCode } = require('../controllers/companyController');
const router = express.Router();

router.get('/:code', getCompanyByCode);

module.exports = router;
