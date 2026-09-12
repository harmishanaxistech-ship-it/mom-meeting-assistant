const fs = require('fs');
const path = 'src/app.js';
let content = fs.readFileSync(path, 'utf8');

content = content.replace(
  "const teamRoutes = require('./routes/teamRoutes');",
  "const teamRoutes = require('./routes/teamRoutes');\nconst companyRoutes = require('./routes/companyRoutes');"
);

content = content.replace(
  "app.use('/api/team', teamRoutes);",
  "app.use('/api/team', teamRoutes);\napp.use('/api/companies', companyRoutes);"
);

fs.writeFileSync(path, content);
