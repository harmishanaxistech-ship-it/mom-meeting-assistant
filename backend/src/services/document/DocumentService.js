const PDFDocument = require('pdfkit');
const { Document: DocxDocument, Packer, Paragraph, TextRun, HeadingLevel, Table, TableRow, TableCell, WidthType, BorderStyle } = require('docx');
const fs = require('fs');
const path = require('path');
const env = require('../../config/env');

class DocumentService {
  constructor() {
    this.fontPath = path.resolve(__dirname, '../../../fonts/ArialUnicode.ttf');
  }

  /**
   * Generate PDF Document from finalized MOM
   * @param {Object} meeting
   * @param {Object} mom
   * @param {string} targetLanguage
   * @returns {Promise<{ filePath: string, fileName: string, fileSize: number }>}
   */
  async generatePDF(meeting, mom, targetLanguage = 'en') {
    return new Promise((resolve, reject) => {
      try {
        const fileName = `MOM_${meeting._id}_${Date.now()}.pdf`;
        const filePath = path.join(env.upload.dir, fileName);
        const doc = new PDFDocument({ margin: 50, size: 'A4' });

        const stream = fs.createWriteStream(filePath);
        doc.pipe(stream);

        // Register Unicode Font (Supports English, Hindi, Gujarati)
        if (fs.existsSync(this.fontPath)) {
          doc.font(this.fontPath);
        }

        // Header Title
        doc.fontSize(22).fillColor('#1E3A8A').text('MINUTES OF MEETING', { align: 'center' });
        doc.moveDown(0.5);
        doc.fontSize(14).fillColor('#334155').text(meeting.title, { align: 'center' });
        doc.moveDown(1);

        // Meeting Info Section
        doc.fontSize(12).fillColor('#0F172A').text(`Meeting Type: ${meeting.meetingType}`);
        doc.text(`Date & Time: ${new Date(meeting.dateTime).toLocaleString()}`);
        if (meeting.location) doc.text(`Location: ${meeting.location}`);
        if (meeting.participants && meeting.participants.length > 0) {
          doc.text(`Participants: ${meeting.participants.join(', ')}`);
        }
        doc.moveDown(1);

        // Horizontal Rule
        doc.strokeColor('#CBD5E1').lineWidth(1).moveTo(50, doc.y).lineTo(545, doc.y).stroke();
        doc.moveDown(1);

        // Executive Summary
        doc.fontSize(14).fillColor('#1E3A8A').text('1. Meeting Summary');
        doc.moveDown(0.3);
        doc.fontSize(10).fillColor('#1E293B').text(mom.meetingSummary || 'N/A', { lineGap: 3 });
        doc.moveDown(1);

        // Agenda
        if (mom.agenda && mom.agenda.length > 0) {
          doc.fontSize(14).fillColor('#1E3A8A').text('2. Agenda');
          doc.moveDown(0.3);
          mom.agenda.forEach((item, idx) => {
            doc.fontSize(10).fillColor('#1E293B').text(`• ${item}`);
          });
          doc.moveDown(1);
        }

        // Key Discussion Points
        if (mom.keyDiscussionPoints && mom.keyDiscussionPoints.length > 0) {
          doc.fontSize(14).fillColor('#1E3A8A').text('3. Key Discussion Points');
          doc.moveDown(0.3);
          mom.keyDiscussionPoints.forEach((point, idx) => {
            doc.fontSize(10).fillColor('#1E293B').text(`${idx + 1}. ${point}`, { lineGap: 2 });
          });
          doc.moveDown(1);
        }

        // Decisions
        if (mom.decisions && mom.decisions.length > 0) {
          doc.fontSize(14).fillColor('#1E3A8A').text('4. Decisions Taken');
          doc.moveDown(0.3);
          mom.decisions.forEach((dec) => {
            doc.fontSize(10).fillColor('#10B981').text(`✓ ${dec}`, { lineGap: 2 });
          });
          doc.moveDown(1);
        }

        // Action Items
        if (mom.actionItems && mom.actionItems.length > 0) {
          doc.fontSize(14).fillColor('#1E3A8A').text('5. Action Items');
          doc.moveDown(0.5);

          mom.actionItems.forEach((item, idx) => {
            doc.fontSize(10).fillColor('#0F172A').text(`Task ${idx + 1}: ${item.task}`);
            doc.fillColor('#64748B').text(`   Owner: ${item.owner || 'Unassigned'}  |  Due: ${item.deadline || 'TBD'}  |  Priority: ${item.priority || 'Medium'}`);
            doc.moveDown(0.3);
          });
          doc.moveDown(1);
        }

        // Conclusion / Next Steps
        if (mom.conclusion) {
          doc.fontSize(14).fillColor('#1E3A8A').text('6. Conclusion');
          doc.moveDown(0.3);
          doc.fontSize(10).fillColor('#1E293B').text(mom.conclusion);
        }

        doc.end();

        stream.on('finish', () => {
          const stats = fs.statSync(filePath);
          resolve({
            filePath,
            fileName,
            fileSize: stats.size,
          });
        });

        stream.on('error', reject);
      } catch (err) {
        reject(err);
      }
    });
  }

  /**
   * Generate DOCX Document from finalized MOM
   * @param {Object} meeting
   * @param {Object} mom
   * @param {string} targetLanguage
   * @returns {Promise<{ filePath: string, fileName: string, fileSize: number }>}
   */
  async generateDOCX(meeting, mom, targetLanguage = 'en') {
    const fileName = `MOM_${meeting._id}_${Date.now()}.docx`;
    const filePath = path.join(env.upload.dir, fileName);

    const docChildren = [
      new Paragraph({
        text: 'MINUTES OF MEETING',
        heading: HeadingLevel.HEADING_1,
      }),
      new Paragraph({
        text: meeting.title,
        heading: HeadingLevel.HEADING_2,
      }),
      new Paragraph({
        children: [
          new TextRun({ text: `Type: ${meeting.meetingType}`, bold: true }),
          new TextRun({ text: ` | Date: ${new Date(meeting.dateTime).toLocaleString()}` }),
        ],
      }),
      new Paragraph({ text: '' }),
      new Paragraph({
        text: '1. Executive Summary',
        heading: HeadingLevel.HEADING_3,
      }),
      new Paragraph({
        text: mom.meetingSummary || 'N/A',
      }),
      new Paragraph({ text: '' }),
    ];

    // Key Discussion Points
    if (mom.keyDiscussionPoints && mom.keyDiscussionPoints.length > 0) {
      docChildren.push(
        new Paragraph({
          text: '2. Key Discussion Points',
          heading: HeadingLevel.HEADING_3,
        })
      );
      mom.keyDiscussionPoints.forEach((point, i) => {
        docChildren.push(new Paragraph({ text: `${i + 1}. ${point}` }));
      });
      docChildren.push(new Paragraph({ text: '' }));
    }

    // Decisions
    if (mom.decisions && mom.decisions.length > 0) {
      docChildren.push(
        new Paragraph({
          text: '3. Decisions',
          heading: HeadingLevel.HEADING_3,
        })
      );
      mom.decisions.forEach((dec) => {
        docChildren.push(new Paragraph({ text: `• ${dec}` }));
      });
      docChildren.push(new Paragraph({ text: '' }));
    }

    // Action Items
    if (mom.actionItems && mom.actionItems.length > 0) {
      docChildren.push(
        new Paragraph({
          text: '4. Action Items',
          heading: HeadingLevel.HEADING_3,
        })
      );
      mom.actionItems.forEach((act, i) => {
        docChildren.push(
          new Paragraph({
            children: [
              new TextRun({ text: `Task ${i + 1}: ${act.task}\n`, bold: true }),
              new TextRun({ text: `Owner: ${act.owner || 'Unassigned'} | Due: ${act.deadline || 'TBD'} | Priority: ${act.priority || 'Medium'}` }),
            ],
          })
        );
      });
      docChildren.push(new Paragraph({ text: '' }));
    }

    if (mom.conclusion) {
      docChildren.push(
        new Paragraph({
          text: '5. Conclusion',
          heading: HeadingLevel.HEADING_3,
        }),
        new Paragraph({ text: mom.conclusion })
      );
    }

    const doc = new DocxDocument({
      sections: [{ properties: {}, children: docChildren }],
    });

    const buffer = await Packer.toBuffer(doc);
    fs.writeFileSync(filePath, buffer);
    const stats = fs.statSync(filePath);

    return {
      filePath,
      fileName,
      fileSize: stats.size,
    };
  }
}

module.exports = new DocumentService();
