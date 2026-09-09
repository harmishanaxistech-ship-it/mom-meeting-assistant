const PDFDocument = require('pdfkit');
const { Document: DocxDocument, Packer, Paragraph, TextRun, HeadingLevel, Table, TableRow, TableCell, WidthType, BorderStyle } = require('docx');
const ExcelJS = require('exceljs');
const fs = require('fs');
const path = require('path');
const env = require('../../config/env');

class DocumentService {
  constructor() {
    this.fontPath = path.resolve(__dirname, '../../../fonts/ArialUnicode.ttf');
    this.excelTemplatePath = path.resolve(__dirname, '../../../templates/MOM_Template.xlsx');
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

        // Other Notes / Informal Remarks
        if (mom.otherNotes && mom.otherNotes.length > 0) {
          doc.fontSize(14).fillColor('#475569').text('6. Other Notes & Informal Discussions');
          doc.moveDown(0.3);
          mom.otherNotes.forEach((note, idx) => {
            doc.fontSize(10).fillColor('#64748B').text(`• ${note}`, { lineGap: 2 });
          });
          doc.moveDown(1);
        }

        // Conclusion / Next Steps
        if (mom.conclusion) {
          doc.fontSize(14).fillColor('#1E3A8A').text('7. Conclusion');
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

    // Other Notes / Informal Remarks
    if (mom.otherNotes && mom.otherNotes.length > 0) {
      docChildren.push(
        new Paragraph({
          text: '5. Other Notes & Informal Discussions',
          heading: HeadingLevel.HEADING_3,
        })
      );
      mom.otherNotes.forEach((note) => {
        docChildren.push(
          new Paragraph({
            children: [
              new TextRun({ text: `• ${note}` }),
            ],
          })
        );
      });
      docChildren.push(new Paragraph({ text: '' }));
    }

    if (mom.conclusion) {
      docChildren.push(
        new Paragraph({
          text: '6. Conclusion',
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

  /**
   * Generate XLSX Document from finalized MOM using Excel Template
   * @param {Object} meeting
   * @param {Object} mom
   * @param {string} targetLanguage
   * @returns {Promise<{ filePath: string, fileName: string, fileSize: number }>}
   */
  async generateXLSX(meeting, mom, targetLanguage = 'en') {
    const fileName = `MOM_${meeting._id}_${Date.now()}.xlsx`;
    const filePath = path.join(env.upload.dir, fileName);
    const templatePath = fs.existsSync(this.excelTemplatePath)
      ? this.excelTemplatePath
      : path.resolve(__dirname, '../../../prompts/MOM Format_8986.xlsx');

    const workbook = new ExcelJS.Workbook();
    if (fs.existsSync(templatePath)) {
      await workbook.xlsx.readFile(templatePath);
    } else {
      workbook.addWorksheet('Meetings (MOM)');
      workbook.addWorksheet('Tasks');
      workbook.addWorksheet('MOM Print');
    }

    const momId = `MOM-${(meeting._id || '001').toString().slice(-3).toUpperCase()}`;
    const meetingDate = meeting.dateTime ? new Date(meeting.dateTime) : new Date();
    const actionItems = Array.isArray(mom.actionItems) ? mom.actionItems : [];
    const attendeesStr = Array.isArray(meeting.participants) ? meeting.participants.join(', ') : '';

    const startTimeStr = meeting.dateTime
      ? new Date(meeting.dateTime).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
      : '10:00 AM';

    let endTimeStr = '11:00 AM';
    if (meeting.dateTime && meeting.duration) {
      const endTime = new Date(new Date(meeting.dateTime).getTime() + meeting.duration * 1000);
      endTimeStr = endTime.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    }

    let agendaText = '';
    if (Array.isArray(mom.agenda) && mom.agenda.length > 0) {
      agendaText = mom.agenda.map((item, idx) => `${idx + 1}. ${item}`).join('  ');
    } else if (typeof mom.agenda === 'string') {
      agendaText = mom.agenda;
    }

    let decisionsText = '';
    if (Array.isArray(mom.decisions) && mom.decisions.length > 0) {
      decisionsText = mom.decisions.join('; ');
    } else if (typeof mom.decisions === 'string') {
      decisionsText = mom.decisions;
    }

    let nextMeetingDate = null;
    if (mom.nextMeeting && mom.nextMeeting.date) {
      const parsedNext = new Date(mom.nextMeeting.date);
      nextMeetingDate = isNaN(parsedNext.getTime()) ? mom.nextMeeting.date : parsedNext;
    }

    // ==========================================
    // 1. POPULATE 'Meetings (MOM)' SHEET
    // ==========================================
    const momSheet = workbook.getWorksheet('Meetings (MOM)');
    if (momSheet) {
      // Clear old template dummy rows
      for (let r = 3; r <= Math.max(momSheet.rowCount, 10); r++) {
        const dummyRow = momSheet.getRow(r);
        dummyRow.getCell(1).value = null;
        dummyRow.commit();
      }

      const momRow = momSheet.getRow(2);
      momRow.getCell(1).value = momId;
      momRow.getCell(2).value = meetingDate;
      momRow.getCell(3).value = meeting.location || 'Head Office';
      momRow.getCell(4).value = meeting.title || 'Meeting';
      momRow.getCell(5).value = meeting.meetingType || 'General Meeting';
      momRow.getCell(6).value = meeting.location || 'Conference Room / Online';
      momRow.getCell(7).value = startTimeStr;
      momRow.getCell(8).value = endTimeStr;
      momRow.getCell(9).value = (meeting.participants && meeting.participants[0]) || 'Meeting Lead';
      momRow.getCell(10).value = 'NoteAX AI';
      momRow.getCell(11).value = attendeesStr;
      momRow.getCell(12).value = '';
      momRow.getCell(13).value = agendaText;
      momRow.getCell(14).value = mom.meetingSummary || '';
      momRow.getCell(15).value = decisionsText;
      momRow.getCell(16).value = nextMeetingDate;
      momRow.getCell(17).value = { formula: 'IF($A2="","",COUNTIFS(Tasks!$B$2:$B$501,$A2))', result: actionItems.length };
      momRow.getCell(18).value = { formula: 'IF($A2="","",COUNTIFS(Tasks!$B$2:$B$501,$A2,Tasks!$L$2:$L$501,"Completed"))', result: 0 };
      momRow.getCell(19).value = { formula: 'IF($A2="","",$Q2-$R2)', result: actionItems.length };
      momRow.getCell(20).value = { formula: 'IF($A2="","",SUMIFS(Tasks!$T$2:$T$501,Tasks!$B$2:$B$501,$A2))', result: 0 };
      momRow.getCell(21).value = { formula: 'IF($A2="","",IF($Q2=0,"",$R2/$Q2))', result: 0 };
      momRow.commit();
    }

    // ==========================================
    // 2. POPULATE 'Tasks' SHEET
    // ==========================================
    const taskSheet = workbook.getWorksheet('Tasks');
    if (taskSheet) {
      // Clear old template dummy rows
      const maxRows = Math.max(taskSheet.rowCount, 20);
      for (let r = 2; r <= maxRows; r++) {
        if (r >= 2 + actionItems.length) {
          const emptyRow = taskSheet.getRow(r);
          for (let c = 1; c <= 20; c++) {
            emptyRow.getCell(c).value = null;
          }
          emptyRow.commit();
        }
      }

      actionItems.forEach((act, idx) => {
        const rowNum = 2 + idx;
        const taskRow = taskSheet.getRow(rowNum);
        const taskId = `T-${String(idx + 1).padStart(3, '0')}`;
        let deadlineVal = meetingDate;
        if (act.deadline) {
          const parsed = new Date(act.deadline);
          deadlineVal = isNaN(parsed.getTime()) ? act.deadline : parsed;
        }

        taskRow.getCell(1).value = taskId;
        taskRow.getCell(2).value = momId;
        taskRow.getCell(3).value = { formula: `IF($B${rowNum}="","",IFERROR(INDEX('Meetings (MOM)'!$B$2:$B$201,MATCH($B${rowNum},'Meetings (MOM)'!$A$2:$A$201,0)),""))`, result: meetingDate };
        taskRow.getCell(4).value = { formula: `IF($B${rowNum}="","",IFERROR(INDEX('Meetings (MOM)'!$C$2:$C$201,MATCH($B${rowNum},'Meetings (MOM)'!$A$2:$A$201,0)),""))`, result: meeting.location || 'Head Office' };
        taskRow.getCell(5).value = act.task || '';
        taskRow.getCell(6).value = act.owner || 'Unassigned';
        taskRow.getCell(7).value = (meeting.participants && meeting.participants[0]) || 'EA to Director';
        taskRow.getCell(8).value = act.priority || 'Medium';
        taskRow.getCell(9).value = meetingDate;
        taskRow.getCell(10).value = deadlineVal;
        taskRow.getCell(11).value = null;
        taskRow.getCell(12).value = act.status || 'Not Started';
        taskRow.getCell(13).value = 0;
        taskRow.getCell(14).value = null;
        taskRow.getCell(15).value = { formula: `IF(OR($A${rowNum}="",IF($K${rowNum}="",$J${rowNum},$K${rowNum})=""),"",IF($L${rowNum}="Completed",IF($N${rowNum}="","",$N${rowNum}-IF($K${rowNum}="",$J${rowNum},$K${rowNum})),IF($L${rowNum}="Cancelled","",TODAY()-IF($K${rowNum}="",$J${rowNum},$K${rowNum}))))`, result: 0 };
        taskRow.getCell(16).value = null;
        taskRow.getCell(17).value = { formula: `IF($A${rowNum}="","",IF(OR($L${rowNum}="Completed",$L${rowNum}="Cancelled"),"Closed",IF(IF($K${rowNum}="",$J${rowNum},$K${rowNum})="","Set deadline",IF(TODAY()>IF($K${rowNum}="",$J${rowNum},$K${rowNum}),"OVERDUE - Escalate",IF(IF($K${rowNum}="",$J${rowNum},$K${rowNum})-TODAY()<=3,"Send Reminder","On Track")))))`, result: 'On Track' };
        taskRow.getCell(18).value = null;
        taskRow.getCell(19).value = { formula: `IF($B${rowNum}="","",$B${rowNum}&"-"&COUNTIFS($B$2:$B${rowNum},$B${rowNum}))`, result: `${momId}-${idx + 1}` };
        taskRow.getCell(20).value = { formula: `IF($A${rowNum}="",0,IF(OR($L${rowNum}="Completed",$L${rowNum}="Cancelled"),0,IF(IF($K${rowNum}="",$J${rowNum},$K${rowNum})="",0,IF(TODAY()>IF($K${rowNum}="",$J${rowNum},$K${rowNum}),1,0))))`, result: 0 };
        taskRow.commit();
      });
    }

    // ==========================================
    // 3. POPULATE 'MOM Print' SHEET
    // ==========================================
    const printSheet = workbook.getWorksheet('MOM Print');
    if (printSheet) {
      printSheet.getCell('C4').value = momId;

      printSheet.getCell('C6').value = { formula: "IFERROR(INDEX('Meetings (MOM)'!$B$2:$B$201,MATCH($C$4,'Meetings (MOM)'!$A$2:$A$201,0)),\"\")", result: meetingDate };
      printSheet.getCell('E6').value = { formula: "IFERROR(INDEX('Meetings (MOM)'!$C$2:$C$201,MATCH($C$4,'Meetings (MOM)'!$A$2:$A$201,0)),\"\")", result: meeting.location || 'Head Office' };
      printSheet.getCell('C7').value = { formula: "IFERROR(INDEX('Meetings (MOM)'!$D$2:$D$201,MATCH($C$4,'Meetings (MOM)'!$A$2:$A$201,0)),\"\")", result: meeting.title || 'Meeting' };
      printSheet.getCell('E7').value = { formula: "IFERROR(INDEX('Meetings (MOM)'!$E$2:$E$201,MATCH($C$4,'Meetings (MOM)'!$A$2:$A$201,0)),\"\")", result: meeting.meetingType || 'General Meeting' };
      printSheet.getCell('C8').value = { formula: "IFERROR(INDEX('Meetings (MOM)'!$F$2:$F$201,MATCH($C$4,'Meetings (MOM)'!$A$2:$A$201,0)),\"\")", result: meeting.location || 'Conference Room / Online' };
      printSheet.getCell('E8').value = { formula: "IFERROR(INDEX('Meetings (MOM)'!$P$2:$P$201,MATCH($C$4,'Meetings (MOM)'!$A$2:$A$201,0)),\"\")", result: nextMeetingDate || '' };
      printSheet.getCell('C9').value = { formula: "IFERROR(INDEX('Meetings (MOM)'!$G$2:$G$201,MATCH($C$4,'Meetings (MOM)'!$A$2:$A$201,0)),\"\")", result: startTimeStr };
      printSheet.getCell('E9').value = { formula: "IFERROR(INDEX('Meetings (MOM)'!$H$2:$H$201,MATCH($C$4,'Meetings (MOM)'!$A$2:$A$201,0)),\"\")", result: endTimeStr };
      printSheet.getCell('C10').value = { formula: "IFERROR(INDEX('Meetings (MOM)'!$I$2:$I$201,MATCH($C$4,'Meetings (MOM)'!$A$2:$A$201,0)),\"\")", result: (meeting.participants && meeting.participants[0]) || 'Meeting Lead' };
      printSheet.getCell('E10').value = { formula: "IFERROR(INDEX('Meetings (MOM)'!$J$2:$J$201,MATCH($C$4,'Meetings (MOM)'!$A$2:$A$201,0)),\"\")", result: 'NoteAX AI' };

      // Narrative Blocks
      for (let c = 2; c <= 9; c++) {
        printSheet.getRow(13).getCell(c).value = { formula: "IFERROR(INDEX('Meetings (MOM)'!$K$2:$K$201,MATCH($C$4,'Meetings (MOM)'!$A$2:$A$201,0)),\"\")", result: attendeesStr };
        printSheet.getRow(15).getCell(c).value = { formula: "IFERROR(INDEX('Meetings (MOM)'!$L$2:$L$201,MATCH($C$4,'Meetings (MOM)'!$A$2:$A$201,0)),\"\")", result: '' };
        printSheet.getRow(18).getCell(c).value = { formula: "IFERROR(INDEX('Meetings (MOM)'!$M$2:$M$201,MATCH($C$4,'Meetings (MOM)'!$A$2:$A$201,0)),\"\")", result: agendaText };
        printSheet.getRow(21).getCell(c).value = { formula: "IFERROR(INDEX('Meetings (MOM)'!$N$2:$N$201,MATCH($C$4,'Meetings (MOM)'!$A$2:$A$201,0)),\"\")", result: mom.meetingSummary || '' };
        printSheet.getRow(24).getCell(c).value = { formula: "IFERROR(INDEX('Meetings (MOM)'!$O$2:$O$201,MATCH($C$4,'Meetings (MOM)'!$A$2:$A$201,0)),\"\")", result: decisionsText };
      }

      // Action Points Table (Rows 28 to 42)
      for (let i = 0; i < 15; i++) {
        const rowNum = 28 + i;
        const taskRow = printSheet.getRow(rowNum);
        const act = actionItems[i];

        if (act) {
          let deadlineVal = meetingDate;
          if (act.deadline) {
            const parsed = new Date(act.deadline);
            deadlineVal = isNaN(parsed.getTime()) ? act.deadline : parsed;
          }
          taskRow.getCell(2).value = { formula: `IFERROR(INDEX(Tasks!$A$2:$A$501,MATCH($C$4&"-"&${i + 1},Tasks!$S$2:$S$501,0)),"")`, result: `T-${String(i + 1).padStart(3, '0')}` };
          taskRow.getCell(3).value = { formula: `IFERROR(INDEX(Tasks!$E$2:$E$501,MATCH($C$4&"-"&${i + 1},Tasks!$S$2:$S$501,0)),"")`, result: act.task || '' };
          taskRow.getCell(4).value = { formula: `IFERROR(INDEX(Tasks!$F$2:$F$501,MATCH($C$4&"-"&${i + 1},Tasks!$S$2:$S$501,0)),"")`, result: act.owner || 'Unassigned' };
          taskRow.getCell(5).value = { formula: `IFERROR(INDEX(Tasks!$G$2:$G$501,MATCH($C$4&"-"&${i + 1},Tasks!$S$2:$S$501,0)),"")`, result: (meeting.participants && meeting.participants[0]) || 'EA to Director' };
          taskRow.getCell(6).value = { formula: `IFERROR(INDEX(Tasks!$H$2:$H$501,MATCH($C$4&"-"&${i + 1},Tasks!$S$2:$S$501,0)),"")`, result: act.priority || 'Medium' };
          taskRow.getCell(7).value = { formula: `IFERROR(IF(INDEX(Tasks!$K$2:$K$501,MATCH($C$4&"-"&${i + 1},Tasks!$S$2:$S$501,0))="",INDEX(Tasks!$J$2:$J$501,MATCH($C$4&"-"&${i + 1},Tasks!$S$2:$S$501,0)),INDEX(Tasks!$K$2:$K$501,MATCH($C$4&"-"&${i + 1},Tasks!$S$2:$S$501,0))),"")`, result: deadlineVal };
          taskRow.getCell(8).value = { formula: `IFERROR(INDEX(Tasks!$L$2:$L$501,MATCH($C$4&"-"&${i + 1},Tasks!$S$2:$S$501,0)),"")`, result: act.status || 'Not Started' };
          taskRow.getCell(9).value = { formula: `IFERROR(INDEX(Tasks!$M$2:$M$501,MATCH($C$4&"-"&${i + 1},Tasks!$S$2:$S$501,0)),"")`, result: 0 };
        } else {
          taskRow.getCell(2).value = { formula: `IFERROR(INDEX(Tasks!$A$2:$A$501,MATCH($C$4&"-"&${i + 1},Tasks!$S$2:$S$501,0)),"")`, result: '' };
          taskRow.getCell(3).value = { formula: `IFERROR(INDEX(Tasks!$E$2:$E$501,MATCH($C$4&"-"&${i + 1},Tasks!$S$2:$S$501,0)),"")`, result: '' };
          taskRow.getCell(4).value = { formula: `IFERROR(INDEX(Tasks!$F$2:$F$501,MATCH($C$4&"-"&${i + 1},Tasks!$S$2:$S$501,0)),"")`, result: '' };
          taskRow.getCell(5).value = { formula: `IFERROR(INDEX(Tasks!$G$2:$G$501,MATCH($C$4&"-"&${i + 1},Tasks!$S$2:$S$501,0)),"")`, result: '' };
          taskRow.getCell(6).value = { formula: `IFERROR(INDEX(Tasks!$H$2:$H$501,MATCH($C$4&"-"&${i + 1},Tasks!$S$2:$S$501,0)),"")`, result: '' };
          taskRow.getCell(7).value = { formula: `IFERROR(IF(INDEX(Tasks!$K$2:$K$501,MATCH($C$4&"-"&${i + 1},Tasks!$S$2:$S$501,0))="",INDEX(Tasks!$J$2:$J$501,MATCH($C$4&"-"&${i + 1},Tasks!$S$2:$S$501,0)),INDEX(Tasks!$K$2:$K$501,MATCH($C$4&"-"&${i + 1},Tasks!$S$2:$S$501,0))),"")`, result: '' };
          taskRow.getCell(8).value = { formula: `IFERROR(INDEX(Tasks!$L$2:$L$501,MATCH($C$4&"-"&${i + 1},Tasks!$S$2:$S$501,0)),"")`, result: '' };
          taskRow.getCell(9).value = { formula: `IFERROR(INDEX(Tasks!$M$2:$M$501,MATCH($C$4&"-"&${i + 1},Tasks!$S$2:$S$501,0)),"")`, result: '' };
        }
        taskRow.commit();
      }

      printSheet.getCell('C44').value = { formula: "IFERROR(INDEX('Meetings (MOM)'!$J$2:$J$201,MATCH($C$4,'Meetings (MOM)'!$A$2:$A$201,0)),\"\")", result: 'NoteAX AI' };
      printSheet.getCell('F44').value = { formula: "IFERROR(INDEX('Meetings (MOM)'!$I$2:$I$201,MATCH($C$4,'Meetings (MOM)'!$A$2:$A$201,0)),\"\")", result: (meeting.participants && meeting.participants[0]) || 'Meeting Lead' };
    }

    await workbook.xlsx.writeFile(filePath);
    const stats = fs.statSync(filePath);

    return {
      filePath,
      fileName,
      fileSize: stats.size,
    };
  }

  /**
   * Append or update a meeting and its tasks in the central static Master Excel Tracker
   * @param {Object} meeting
   * @param {Object} mom
   * @returns {Promise<{ filePath: string, fileName: string, fileSize: number }>}
   */
  async syncToMasterTracker(meeting, mom) {
    const masterPath = path.join(env.upload.dir, 'MOM_Master_Tracker.xlsx');
    const promptsMasterPath = path.resolve(__dirname, '../../../prompts/MOM_Master_Tracker.xlsx');
    const templatePath = fs.existsSync(this.excelTemplatePath)
      ? this.excelTemplatePath
      : path.resolve(__dirname, '../../../prompts/MOM Format_8986.xlsx');

    const workbook = new ExcelJS.Workbook();
    if (fs.existsSync(masterPath)) {
      await workbook.xlsx.readFile(masterPath);
    } else if (fs.existsSync(promptsMasterPath)) {
      await workbook.xlsx.readFile(promptsMasterPath);
    } else if (fs.existsSync(templatePath)) {
      await workbook.xlsx.readFile(templatePath);
    } else {
      workbook.addWorksheet('Meetings (MOM)');
      workbook.addWorksheet('Tasks');
      workbook.addWorksheet('MOM Print');
    }

    const momId = `MOM-${(meeting._id || '001').toString().slice(-3).toUpperCase()}`;
    const meetingDate = meeting.dateTime ? new Date(meeting.dateTime) : new Date();
    const actionItems = Array.isArray(mom.actionItems) ? mom.actionItems : [];
    const attendeesStr = Array.isArray(meeting.participants) ? meeting.participants.join(', ') : '';

    const startTimeStr = meeting.dateTime
      ? new Date(meeting.dateTime).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
      : '10:00 AM';

    let endTimeStr = '11:00 AM';
    if (meeting.dateTime && meeting.duration) {
      const endTime = new Date(new Date(meeting.dateTime).getTime() + meeting.duration * 1000);
      endTimeStr = endTime.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    }

    let agendaText = '';
    if (Array.isArray(mom.agenda) && mom.agenda.length > 0) {
      agendaText = mom.agenda.map((item, idx) => `${idx + 1}. ${item}`).join('  ');
    } else if (typeof mom.agenda === 'string') {
      agendaText = mom.agenda;
    }

    let decisionsText = '';
    if (Array.isArray(mom.decisions) && mom.decisions.length > 0) {
      decisionsText = mom.decisions.join('; ');
    } else if (typeof mom.decisions === 'string') {
      decisionsText = mom.decisions;
    }

    let nextMeetingDate = null;
    if (mom.nextMeeting && mom.nextMeeting.date) {
      const parsedNext = new Date(mom.nextMeeting.date);
      nextMeetingDate = isNaN(parsedNext.getTime()) ? mom.nextMeeting.date : parsedNext;
    }

    // 1. Sync to 'Meetings (MOM)' Sheet
    const momSheet = workbook.getWorksheet('Meetings (MOM)');
    if (momSheet) {
      let targetRowIndex = -1;
      momSheet.eachRow((row, rowNumber) => {
        if (rowNumber >= 2 && row.getCell(1).value === momId) {
          targetRowIndex = rowNumber;
        }
      });

      if (targetRowIndex === -1) {
        targetRowIndex = 2;
        while (momSheet.getRow(targetRowIndex).getCell(1).value) {
          targetRowIndex++;
        }
      }

      const row = momSheet.getRow(targetRowIndex);
      row.getCell(1).value = momId;
      row.getCell(2).value = meetingDate;
      row.getCell(3).value = meeting.location || 'Head Office';
      row.getCell(4).value = meeting.title || 'Meeting';
      row.getCell(5).value = meeting.meetingType || 'General Meeting';
      row.getCell(6).value = meeting.location || 'Conference Room / Online';
      row.getCell(7).value = startTimeStr;
      row.getCell(8).value = endTimeStr;
      row.getCell(9).value = (meeting.participants && meeting.participants[0]) || 'Meeting Lead';
      row.getCell(10).value = 'NoteAX AI';
      row.getCell(11).value = attendeesStr;
      row.getCell(12).value = '';
      row.getCell(13).value = agendaText;
      row.getCell(14).value = mom.meetingSummary || '';
      row.getCell(15).value = decisionsText;
      row.getCell(16).value = nextMeetingDate;
      row.getCell(17).value = { formula: `IF($A${targetRowIndex}="","",COUNTIFS(Tasks!$B$2:$B$501,$A${targetRowIndex}))`, result: actionItems.length };
      row.getCell(18).value = { formula: `IF($A${targetRowIndex}="","",COUNTIFS(Tasks!$B$2:$B$501,$A${targetRowIndex},Tasks!$L$2:$L$501,"Completed"))`, result: 0 };
      row.getCell(19).value = { formula: `IF($A${targetRowIndex}="","",$Q${targetRowIndex}-$R${targetRowIndex})`, result: actionItems.length };
      row.getCell(20).value = { formula: `IF($A${targetRowIndex}="","",SUMIFS(Tasks!$T$2:$T$501,Tasks!$B$2:$B$501,$A${targetRowIndex}))`, result: 0 };
      row.getCell(21).value = { formula: `IF($A${targetRowIndex}="","",IF($Q${targetRowIndex}=0,"",$R${targetRowIndex}/$Q${targetRowIndex}))`, result: 0 };
      row.commit();
    }

    // 2. Sync to 'Tasks' Sheet
    const taskSheet = workbook.getWorksheet('Tasks');
    if (taskSheet && actionItems.length > 0) {
      actionItems.forEach((act, idx) => {
        let taskRowIndex = -1;
        taskSheet.eachRow((r, rNum) => {
          if (rNum >= 2 && r.getCell(2).value === momId && r.getCell(5).value === act.task) {
            taskRowIndex = rNum;
          }
        });

        if (taskRowIndex === -1) {
          taskRowIndex = 2;
          while (taskSheet.getRow(taskRowIndex).getCell(1).value) {
            taskRowIndex++;
          }
        }

        let deadlineVal = meetingDate;
        if (act.deadline) {
          const parsed = new Date(act.deadline);
          deadlineVal = isNaN(parsed.getTime()) ? act.deadline : parsed;
        }

        const taskRow = taskSheet.getRow(taskRowIndex);
        const taskId = `T-${String(taskRowIndex - 1).padStart(3, '0')}`;
        taskRow.getCell(1).value = taskId;
        taskRow.getCell(2).value = momId;
        taskRow.getCell(3).value = { formula: `IF($B${taskRowIndex}="","",IFERROR(INDEX('Meetings (MOM)'!$B$2:$B$201,MATCH($B${taskRowIndex},'Meetings (MOM)'!$A$2:$A$201,0)),""))`, result: meetingDate };
        taskRow.getCell(4).value = { formula: `IF($B${taskRowIndex}="","",IFERROR(INDEX('Meetings (MOM)'!$C$2:$C$201,MATCH($B${taskRowIndex},'Meetings (MOM)'!$A$2:$A$201,0)),""))`, result: meeting.location || 'Head Office' };
        taskRow.getCell(5).value = act.task || '';
        taskRow.getCell(6).value = act.owner || 'Unassigned';
        taskRow.getCell(7).value = (meeting.participants && meeting.participants[0]) || 'EA to Director';
        taskRow.getCell(8).value = act.priority || 'Medium';
        taskRow.getCell(9).value = meetingDate;
        taskRow.getCell(10).value = deadlineVal;
        taskRow.getCell(11).value = null;
        taskRow.getCell(12).value = act.status || 'Not Started';
        taskRow.getCell(13).value = 0;
        taskRow.getCell(14).value = null;
        taskRow.getCell(15).value = { formula: `IF(OR($A${taskRowIndex}="",IF($K${taskRowIndex}="",$J${taskRowIndex},$K${taskRowIndex})=""),"",IF($L${taskRowIndex}="Completed",IF($N${taskRowIndex}="","",$N${taskRowIndex}-IF($K${taskRowIndex}="",$J${taskRowIndex},$K${taskRowIndex})),IF($L${taskRowIndex}="Cancelled","",TODAY()-IF($K${taskRowIndex}="",$J${taskRowIndex},$K${taskRowIndex}))))`, result: 0 };
        taskRow.getCell(16).value = null;
        taskRow.getCell(17).value = { formula: `IF($A${taskRowIndex}="","",IF(OR($L${taskRowIndex}="Completed",$L${taskRowIndex}="Cancelled"),"Closed",IF(IF($K${taskRowIndex}="",$J${taskRowIndex},$K${taskRowIndex})="","Set deadline",IF(TODAY()>IF($K${taskRowIndex}="",$J${taskRowIndex},$K${taskRowIndex}),"OVERDUE - Escalate",IF(IF($K${taskRowIndex}="",$J${taskRowIndex},$K${taskRowIndex})-TODAY()<=3,"Send Reminder","On Track")))))`, result: 'On Track' };
        taskRow.getCell(18).value = null;
        taskRow.getCell(19).value = { formula: `IF($B${taskRowIndex}="","",$B${taskRowIndex}&"-"&COUNTIFS($B$2:$B${taskRowIndex},$B${taskRowIndex}))`, result: `${momId}-${idx + 1}` };
        taskRow.getCell(20).value = { formula: `IF($A${taskRowIndex}="",0,IF(OR($L${taskRowIndex}="Completed",$L${taskRowIndex}="Cancelled"),0,IF(IF($K${taskRowIndex}="",$J${taskRowIndex},$K${taskRowIndex})="",0,IF(TODAY()>IF($K${taskRowIndex}="",$J${taskRowIndex},$K${taskRowIndex}),1,0))))`, result: 0 };
        taskRow.commit();
      });
    }

    // 3. Set Active MOM ID in 'MOM Print' Sheet
    const printSheet = workbook.getWorksheet('MOM Print');
    if (printSheet) {
      printSheet.getCell('C4').value = momId;

      printSheet.getCell('C6').value = { formula: "IFERROR(INDEX('Meetings (MOM)'!$B$2:$B$201,MATCH($C$4,'Meetings (MOM)'!$A$2:$A$201,0)),\"\")", result: meetingDate };
      printSheet.getCell('E6').value = { formula: "IFERROR(INDEX('Meetings (MOM)'!$C$2:$C$201,MATCH($C$4,'Meetings (MOM)'!$A$2:$A$201,0)),\"\")", result: meeting.location || 'Head Office' };
      printSheet.getCell('C7').value = { formula: "IFERROR(INDEX('Meetings (MOM)'!$D$2:$D$201,MATCH($C$4,'Meetings (MOM)'!$A$2:$A$201,0)),\"\")", result: meeting.title || 'Meeting' };
      printSheet.getCell('E7').value = { formula: "IFERROR(INDEX('Meetings (MOM)'!$E$2:$E$201,MATCH($C$4,'Meetings (MOM)'!$A$2:$A$201,0)),\"\")", result: meeting.meetingType || 'General Meeting' };
      printSheet.getCell('C8').value = { formula: "IFERROR(INDEX('Meetings (MOM)'!$F$2:$F$201,MATCH($C$4,'Meetings (MOM)'!$A$2:$A$201,0)),\"\")", result: meeting.location || 'Conference Room / Online' };
      printSheet.getCell('E8').value = { formula: "IFERROR(INDEX('Meetings (MOM)'!$P$2:$P$201,MATCH($C$4,'Meetings (MOM)'!$A$2:$A$201,0)),\"\")", result: nextMeetingDate || '' };
      printSheet.getCell('C9').value = { formula: "IFERROR(INDEX('Meetings (MOM)'!$G$2:$G$201,MATCH($C$4,'Meetings (MOM)'!$A$2:$A$201,0)),\"\")", result: startTimeStr };
      printSheet.getCell('E9').value = { formula: "IFERROR(INDEX('Meetings (MOM)'!$H$2:$H$201,MATCH($C$4,'Meetings (MOM)'!$A$2:$A$201,0)),\"\")", result: endTimeStr };
      printSheet.getCell('C10').value = { formula: "IFERROR(INDEX('Meetings (MOM)'!$I$2:$I$201,MATCH($C$4,'Meetings (MOM)'!$A$2:$A$201,0)),\"\")", result: (meeting.participants && meeting.participants[0]) || 'Meeting Lead' };
      printSheet.getCell('E10').value = { formula: "IFERROR(INDEX('Meetings (MOM)'!$J$2:$J$201,MATCH($C$4,'Meetings (MOM)'!$A$2:$A$201,0)),\"\")", result: 'NoteAX AI' };

      // Narrative Blocks
      for (let c = 2; c <= 9; c++) {
        printSheet.getRow(13).getCell(c).value = { formula: "IFERROR(INDEX('Meetings (MOM)'!$K$2:$K$201,MATCH($C$4,'Meetings (MOM)'!$A$2:$A$201,0)),\"\")", result: attendeesStr };
        printSheet.getRow(15).getCell(c).value = { formula: "IFERROR(INDEX('Meetings (MOM)'!$L$2:$L$201,MATCH($C$4,'Meetings (MOM)'!$A$2:$A$201,0)),\"\")", result: '' };
        printSheet.getRow(18).getCell(c).value = { formula: "IFERROR(INDEX('Meetings (MOM)'!$M$2:$M$201,MATCH($C$4,'Meetings (MOM)'!$A$2:$A$201,0)),\"\")", result: agendaText };
        printSheet.getRow(21).getCell(c).value = { formula: "IFERROR(INDEX('Meetings (MOM)'!$N$2:$N$201,MATCH($C$4,'Meetings (MOM)'!$A$2:$A$201,0)),\"\")", result: mom.meetingSummary || '' };
        printSheet.getRow(24).getCell(c).value = { formula: "IFERROR(INDEX('Meetings (MOM)'!$O$2:$O$201,MATCH($C$4,'Meetings (MOM)'!$A$2:$A$201,0)),\"\")", result: decisionsText };
      }

      // Action Points Table (Rows 28 to 42)
      for (let i = 0; i < 15; i++) {
        const rowNum = 28 + i;
        const taskRow = printSheet.getRow(rowNum);
        const act = actionItems[i];

        if (act) {
          let deadlineVal = meetingDate;
          if (act.deadline) {
            const parsed = new Date(act.deadline);
            deadlineVal = isNaN(parsed.getTime()) ? act.deadline : parsed;
          }
          taskRow.getCell(2).value = { formula: `IFERROR(INDEX(Tasks!$A$2:$A$501,MATCH($C$4&"-"&${i + 1},Tasks!$S$2:$S$501,0)),"")`, result: `T-${String(i + 1).padStart(3, '0')}` };
          taskRow.getCell(3).value = { formula: `IFERROR(INDEX(Tasks!$E$2:$E$501,MATCH($C$4&"-"&${i + 1},Tasks!$S$2:$S$501,0)),"")`, result: act.task || '' };
          taskRow.getCell(4).value = { formula: `IFERROR(INDEX(Tasks!$F$2:$F$501,MATCH($C$4&"-"&${i + 1},Tasks!$S$2:$S$501,0)),"")`, result: act.owner || 'Unassigned' };
          taskRow.getCell(5).value = { formula: `IFERROR(INDEX(Tasks!$G$2:$G$501,MATCH($C$4&"-"&${i + 1},Tasks!$S$2:$S$501,0)),"")`, result: (meeting.participants && meeting.participants[0]) || 'EA to Director' };
          taskRow.getCell(6).value = { formula: `IFERROR(INDEX(Tasks!$H$2:$H$501,MATCH($C$4&"-"&${i + 1},Tasks!$S$2:$S$501,0)),"")`, result: act.priority || 'Medium' };
          taskRow.getCell(7).value = { formula: `IFERROR(IF(INDEX(Tasks!$K$2:$K$501,MATCH($C$4&"-"&${i + 1},Tasks!$S$2:$S$501,0))="",INDEX(Tasks!$J$2:$J$501,MATCH($C$4&"-"&${i + 1},Tasks!$S$2:$S$501,0)),INDEX(Tasks!$K$2:$K$501,MATCH($C$4&"-"&${i + 1},Tasks!$S$2:$S$501,0))),"")`, result: deadlineVal };
          taskRow.getCell(8).value = { formula: `IFERROR(INDEX(Tasks!$L$2:$L$501,MATCH($C$4&"-"&${i + 1},Tasks!$S$2:$S$501,0)),"")`, result: act.status || 'Not Started' };
          taskRow.getCell(9).value = { formula: `IFERROR(INDEX(Tasks!$M$2:$M$501,MATCH($C$4&"-"&${i + 1},Tasks!$S$2:$S$501,0)),"")`, result: 0 };
        } else {
          taskRow.getCell(2).value = { formula: `IFERROR(INDEX(Tasks!$A$2:$A$501,MATCH($C$4&"-"&${i + 1},Tasks!$S$2:$S$501,0)),"")`, result: '' };
          taskRow.getCell(3).value = { formula: `IFERROR(INDEX(Tasks!$E$2:$E$501,MATCH($C$4&"-"&${i + 1},Tasks!$S$2:$S$501,0)),"")`, result: '' };
          taskRow.getCell(4).value = { formula: `IFERROR(INDEX(Tasks!$F$2:$F$501,MATCH($C$4&"-"&${i + 1},Tasks!$S$2:$S$501,0)),"")`, result: '' };
          taskRow.getCell(5).value = { formula: `IFERROR(INDEX(Tasks!$G$2:$G$501,MATCH($C$4&"-"&${i + 1},Tasks!$S$2:$S$501,0)),"")`, result: '' };
          taskRow.getCell(6).value = { formula: `IFERROR(INDEX(Tasks!$H$2:$H$501,MATCH($C$4&"-"&${i + 1},Tasks!$S$2:$S$501,0)),"")`, result: '' };
          taskRow.getCell(7).value = { formula: `IFERROR(IF(INDEX(Tasks!$K$2:$K$501,MATCH($C$4&"-"&${i + 1},Tasks!$S$2:$S$501,0))="",INDEX(Tasks!$J$2:$J$501,MATCH($C$4&"-"&${i + 1},Tasks!$S$2:$S$501,0)),INDEX(Tasks!$K$2:$K$501,MATCH($C$4&"-"&${i + 1},Tasks!$S$2:$S$501,0))),"")`, result: '' };
          taskRow.getCell(8).value = { formula: `IFERROR(INDEX(Tasks!$L$2:$L$501,MATCH($C$4&"-"&${i + 1},Tasks!$S$2:$S$501,0)),"")`, result: '' };
          taskRow.getCell(9).value = { formula: `IFERROR(INDEX(Tasks!$M$2:$M$501,MATCH($C$4&"-"&${i + 1},Tasks!$S$2:$S$501,0)),"")`, result: '' };
        }
        taskRow.commit();
      }

      printSheet.getCell('C44').value = { formula: "IFERROR(INDEX('Meetings (MOM)'!$J$2:$J$201,MATCH($C$4,'Meetings (MOM)'!$A$2:$A$201,0)),\"\")", result: 'NoteAX AI' };
      printSheet.getCell('F44').value = { formula: "IFERROR(INDEX('Meetings (MOM)'!$I$2:$I$201,MATCH($C$4,'Meetings (MOM)'!$A$2:$A$201,0)),\"\")", result: (meeting.participants && meeting.participants[0]) || 'Meeting Lead' };
    }

    await workbook.xlsx.writeFile(masterPath);
    try {
      await workbook.xlsx.writeFile(promptsMasterPath);
    } catch (e) {}

    const stats = fs.statSync(masterPath);
    return {
      filePath: masterPath,
      fileName: 'MOM_Master_Tracker.xlsx',
      fileSize: stats.size,
    };
  }
}

module.exports = new DocumentService();
