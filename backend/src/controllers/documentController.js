const Meeting = require('../models/Meeting');
const MOM = require('../models/MOM');
const Document = require('../models/Document');
const documentService = require('../services/document/DocumentService');
const { getTranslationProvider } = require('../services/providerFactory');
const path = require('path');
const fs = require('fs');

/**
 * @desc    Generate export document (PDF or DOCX) in selected language
 * @route   POST /api/meetings/:id/document
 * @access  Private
 */
const generateDocument = async (req, res, next) => {
  try {
    const { format = 'pdf', language = 'en' } = req.body;

    const meeting = await Meeting.findOne({
      _id: req.params.id,
      userId: req.user._id,
    });

    if (!meeting) {
      return res.status(404).json({ success: false, error: 'Meeting not found' });
    }

    let mom = await MOM.findOne({ meetingId: meeting._id });
    if (!mom) {
      return res.status(400).json({
        success: false,
        error: 'No MOM found for this meeting. Please process the meeting first.',
      });
    }

    // Determine content to print based on selected document language
    let momToExport = mom.toObject();

    if (language !== 'en') {
      // Check if translation already cached
      if (mom.translations && mom.translations.get(language)) {
        momToExport = mom.translations.get(language);
      } else if (mom.language === language) {
        momToExport = mom.toObject();
      } else {
        // Translate and cache it
        console.log(`[Document Service] Translating MOM to ${language} for document export...`);
        const translationProvider = getTranslationProvider();
        const translated = await translationProvider.translateMOM(momToExport, language);
        if (!mom.translations) mom.translations = new Map();
        mom.translations.set(language, translated);
        await mom.save();
        momToExport = translated;
      }
    } else {
      // If English requested and main mom is in English
      if (mom.translations && mom.translations.get('en')) {
        momToExport = mom.translations.get('en');
      }
    }

    let docResult;
    if (format.toLowerCase() === 'docx') {
      docResult = await documentService.generateDOCX(meeting, momToExport, language);
    } else {
      docResult = await documentService.generatePDF(meeting, momToExport, language);
    }

    // Save document reference in MongoDB
    const docRecord = await Document.create({
      meetingId: meeting._id,
      momId: mom._id,
      format: format.toLowerCase(),
      language,
      filePath: docResult.filePath,
      fileName: docResult.fileName,
      fileSize: docResult.fileSize,
      mimeType:
        format.toLowerCase() === 'docx'
          ? 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
          : 'application/pdf',
    });

    res.status(201).json({
      success: true,
      message: `${format.toUpperCase()} document generated successfully`,
      data: {
        document: docRecord,
        downloadUrl: `/uploads/${docResult.fileName}`,
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Get all generated documents for meeting
 * @route   GET /api/meetings/:id/document
 * @access  Private
 */
const getDocuments = async (req, res, next) => {
  try {
    const documents = await Document.find({ meetingId: req.params.id }).sort({
      createdAt: -1,
    });

    res.status(200).json({
      success: true,
      count: documents.length,
      data: { documents },
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  generateDocument,
  getDocuments,
};
