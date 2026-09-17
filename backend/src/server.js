require('dotenv').config();
const app = require('./app');

const PORT = process.env.PORT || 4000;

app.listen(PORT, () => {
  // eslint-disable-next-line no-console
  console.log(`Plataforma de Apoyo Académico API escuchando en http://localhost:${PORT}`);
});
