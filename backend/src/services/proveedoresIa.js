// Proveedores de IA del Tutor IA. La aplicación habla con uno solo, elegido con
// IA_PROVEEDOR en backend/.env:
//   - 'gemini' (por defecto): Google Gemini, con nivel gratuito. Clave en
//     https://aistudio.google.com/apikey, en GEMINI_API_KEY.
//   - 'claude': Claude de Anthropic, de pago. Clave en ANTHROPIC_API_KEY.
//
// Los dos reciben los mismos mensajes neutrales:
//   [{ rol: 'usuario' | 'modelo', partes: [{ texto } | { archivo: { mimeType, base64 } }] }]
// y devuelven el texto de la respuesta (JSON si se pasa un esquema).
require('dotenv').config();

/** Error con un código HTTP y un mensaje que se puede mostrar al estudiante. */
class ErrorIa extends Error {
  constructor(status, mensaje) {
    super(mensaje);
    this.status = status;
  }
}

const MAX_TOKENS = 16000;

// ---------------------------------------------------------------- Gemini
const gemini = {
  nombre: 'gemini',
  modelo: process.env.IA_MODELO_GEMINI || 'gemini-3.8-flash',
  clave: () => process.env.GEMINI_API_KEY,
  cliente: null,

  async generar({ instrucciones, mensajes, esquema }) {
    if (!this.cliente) {
      const { GoogleGenAI } = await import('@google/genai');
      this.cliente = new GoogleGenAI({ apiKey: this.clave() });
    }
    const contents = mensajes.map((m) => ({
      role: m.rol === 'modelo' ? 'model' : 'user',
      parts: m.partes.map((p) => (p.archivo
        ? { inlineData: { mimeType: p.archivo.mimeType, data: p.archivo.base64 } }
        : { text: p.texto })),
    }));

    let respuesta;
    try {
      respuesta = await this.cliente.models.generateContent({
        model: this.modelo,
        contents,
        config: {
          systemInstruction: instrucciones,
          maxOutputTokens: MAX_TOKENS,
          ...(esquema ? { responseMimeType: 'application/json', responseJsonSchema: esquema } : {}),
        },
      });
    } catch (err) {
      const status = err.status ?? 0;
      if (status === 429) {
        throw new ErrorIa(429, 'Se alcanzó el límite gratuito de la IA por ahora. Intente de nuevo en un minuto.');
      }
      if (status === 400 && /api key/i.test(err.message)) {
        throw new ErrorIa(503, 'La clave de la API de IA no es válida.');
      }
      if (status === 401 || status === 403) {
        throw new ErrorIa(503, 'La clave de la API de IA no es válida o no tiene permisos.');
      }
      console.error('Error de la API de Gemini:', err.message);
      throw new ErrorIa(502, 'El Tutor IA no respondió. Intente de nuevo en unos minutos.');
    }

    const candidato = respuesta.candidates?.[0];
    const bloqueos = ['SAFETY', 'PROHIBITED_CONTENT', 'BLOCKLIST', 'SPII', 'RECITATION',
      'IMAGE_SAFETY', 'IMAGE_PROHIBITED_CONTENT'];
    if (respuesta.promptFeedback?.blockReason || bloqueos.includes(candidato?.finishReason)) {
      throw new ErrorIa(422, 'La IA no puede responder esta solicitud.');
    }
    if (candidato?.finishReason === 'MAX_TOKENS') {
      throw new ErrorIa(502, 'La respuesta de la IA quedó incompleta. Intente de nuevo.');
    }
    return respuesta.text ?? '';
  },
};

// ---------------------------------------------------------------- Claude
const claude = {
  nombre: 'claude',
  modelo: process.env.IA_MODELO_CLAUDE || 'claude-opus-5-5',
  clave: () => process.env.ANTHROPIC_API_KEY,
  cliente: null,

  async generar({ instrucciones, mensajes, esquema }) {
    const Anthropic = require('@anthropic-ai/sdk');
    if (!this.cliente) this.cliente = new Anthropic();
    const messages = mensajes.map((m) => ({
      role: m.rol === 'modelo' ? 'assistant' : 'user',
      content: m.partes.map((p) => {
        if (!p.archivo) return { type: 'text', text: p.texto };
        const bloque = p.archivo.mimeType === 'application/pdf' ? 'document' : 'image';
        return {
          type: bloque,
          source: { type: 'base64', media_type: p.archivo.mimeType, data: p.archivo.base64 },
          // El archivo se repite en cada pregunta del chat: se cobra completo una vez.
          cache_control: { type: 'ephemeral' },
        };
      }),
    }));

    let respuesta;
    try {
      respuesta = await this.cliente.beta.messages.create({
        model: this.modelo,
        max_tokens: MAX_TOKENS,
        system: instrucciones,
        messages,
        output_config: {
          effort: process.env.IA_ESFUERZO || 'medium',
          ...(esquema ? { format: { type: 'json_schema', schema: esquema } } : {}),
        },
        // Si el modelo declina, la API reintenta con el modelo de respaldo recomendado.
        betas: ['server-side-fallback-2026-07-01'],
        fallbacks: 'default',
      });
    } catch (err) {
      if (err instanceof Anthropic.AuthenticationError || err instanceof Anthropic.PermissionDeniedError) {
        throw new ErrorIa(503, 'La clave de la API de IA no es válida o no tiene permisos.');
      }
      if (err instanceof Anthropic.RateLimitError) {
        throw new ErrorIa(429, 'La IA está recibiendo muchas consultas. Intente de nuevo en un minuto.');
      }
      console.error('Error de la API de Claude:', err.message);
      throw new ErrorIa(502, 'El Tutor IA no respondió. Intente de nuevo en unos minutos.');
    }
    if (respuesta.stop_reason === 'refusal') throw new ErrorIa(422, 'La IA no puede responder esta solicitud.');
    if (respuesta.stop_reason === 'max_tokens') {
      throw new ErrorIa(502, 'La respuesta de la IA quedó incompleta. Intente de nuevo.');
    }
    return respuesta.content.filter((b) => b.type === 'text').map((b) => b.text).join('');
  },
};

// ---------------------------------------------------------------- selección
let proveedorDePrueba = null;

function proveedorActivo() {
  if (proveedorDePrueba) return proveedorDePrueba;
  const elegido = (process.env.IA_PROVEEDOR || '').toLowerCase();
  if (elegido === 'claude') return claude.clave() ? claude : null;
  if (elegido === 'gemini') return gemini.clave() ? gemini : null;
  // Sin elección explícita, se usa el que tenga clave (primero el gratuito).
  if (gemini.clave()) return gemini;
  if (claude.clave()) return claude;
  return null;
}

/** Permite a las pruebas reemplazar la IA por un proveedor falso. */
function usarProveedor(falso) {
  proveedorDePrueba = falso;
}

module.exports = { ErrorIa, proveedorActivo, usarProveedor };
