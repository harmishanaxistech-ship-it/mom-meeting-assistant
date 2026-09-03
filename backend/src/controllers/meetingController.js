const Meeting = require('../models/Meeting');
const Transcript = require('../models/Transcript');
const MOM = require('../models/MOM');
const Document = require('../models/Document');
const ProcessingJob = require('../models/ProcessingJob');

/**
 * @desc    Create a new meeting
 * @route   POST /api/meetings
 * @access  Private
 */
const createMeeting = async (req, res, next) => {
  try {
    const { title, meetingType, dateTime, location, participants, agenda } = req.body;

    if (!title || !title.trim()) {
      return res.status(400).json({
        success: false,
        error: 'Meeting title is required',
      });
    }

    const meeting = await Meeting.create({
      userId: req.user._id,
      title: title.trim(),
      meetingType: meetingType || 'General Meeting',
      dateTime: dateTime ? new Date(dateTime) : new Date(),
      location: location ? location.trim() : '',
      participants: Array.isArray(participants) ? participants : [],
      agenda: agenda ? agenda.trim() : '',
      status: 'created',
    });

    res.status(201).json({
      success: true,
      data: { meeting },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Get all meetings for the logged-in user
 * @route   GET /api/meetings
 * @access  Private
 */
const getMeetings = async (req, res, next) => {
  try {
    const { status, meetingType } = req.query;
    const query = { userId: req.user._id };

    if (status) query.status = status;
    if (meetingType) query.meetingType = meetingType;

    const meetings = await Meeting.find(query).sort({ dateTime: -1, createdAt: -1 });

    res.status(200).json({
      success: true,
      count: meetings.length,
      data: { meetings },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Get single meeting by ID
 * @route   GET /api/meetings/:id
 * @access  Private
 */
const getMeetingById = async (req, res, next) => {
  try {
    const meeting = await Meeting.findOne({
      _id: req.params.id,
      userId: req.user._id,
    });

    if (!meeting) {
      return res.status(404).json({
        success: false,
        error: 'Meeting not found',
      });
    }

    // Include related records if they exist
    const transcript = await Transcript.findOne({ meetingId: meeting._id });
    const mom = await MOM.findOne({ meetingId: meeting._id });
    const documents = await Document.find({ meetingId: meeting._id });
    const processingJob = await ProcessingJob.findOne({ meetingId: meeting._id });

    res.status(200).json({
      success: true,
      data: {
        meeting,
        transcript,
        mom,
        documents,
        processingJob,
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Update meeting details
 * @route   PUT /api/meetings/:id
 * @access  Private
 */
const updateMeeting = async (req, res, next) => {
  try {
    const { title, meetingType, dateTime, location, participants, agenda, status, duration } =
      req.body;

    let meeting = await Meeting.findOne({
      _id: req.params.id,
      userId: req.user._id,
    });

    if (!meeting) {
      return res.status(404).json({
        success: false,
        error: 'Meeting not found',
      });
    }

    if (title !== undefined) meeting.title = title.trim();
    if (meetingType !== undefined) meeting.meetingType = meetingType;
    if (dateTime !== undefined) meeting.dateTime = new Date(dateTime);
    if (location !== undefined) meeting.location = location.trim();
    if (participants !== undefined) meeting.participants = participants;
    if (agenda !== undefined) meeting.agenda = agenda.trim();
    if (status !== undefined) meeting.status = status;
    if (duration !== undefined) meeting.duration = duration;

    await meeting.save();

    res.status(200).json({
      success: true,
      data: { meeting },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Delete meeting and associated data
 * @route   DELETE /api/meetings/:id
 * @access  Private
 */
const deleteMeeting = async (req, res, next) => {
  try {
    const meeting = await Meeting.findOneAndDelete({
      _id: req.params.id,
      userId: req.user._id,
    });

    if (!meeting) {
      return res.status(404).json({
        success: false,
        error: 'Meeting not found',
      });
    }

    // Clean up associated resources
    await Promise.all([
      Transcript.deleteMany({ meetingId: req.params.id }),
      MOM.deleteMany({ meetingId: req.params.id }),
      Document.deleteMany({ meetingId: req.params.id }),
      ProcessingJob.deleteMany({ meetingId: req.params.id }),
    ]);

    res.status(200).json({
      success: true,
      message: 'Meeting and associated records deleted successfully',
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  createMeeting,
  getMeetings,
  getMeetingById,
  updateMeeting,
  deleteMeeting,
};
