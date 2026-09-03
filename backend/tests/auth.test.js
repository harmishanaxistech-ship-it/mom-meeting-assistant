const request = require('supertest');
const app = require('../src/app');
const env = require('../src/config/env');
const { connectDB, disconnectDB } = require('../src/config/db');

beforeAll(async () => {
  await connectDB();
});

afterAll(async () => {
  await disconnectDB();
});

describe('Backend Foundation & Auth Endpoints', () => {
  describe('GET /api/health', () => {
    it('should return 200 and healthy status with provider details', async () => {
      const res = await request(app).get('/api/health');
      expect(res.statusCode).toEqual(200);
      expect(res.body.success).toBe(true);
      expect(res.body.status).toBe('healthy');
      expect(res.body.providers.stt).toBe(env.providers.stt);
    });
  });

  describe('Authentication Flow (/api/auth)', () => {
    it('should reject login with empty credentials', async () => {
      const res = await request(app).post('/api/auth/login').send({});
      expect(res.statusCode).toEqual(400);
      expect(res.body.success).toBe(false);
    });

    it('should reject login with incorrect password', async () => {
      const res = await request(app)
        .post('/api/auth/login')
        .send({ email: env.staticUser.email, password: 'WrongPassword123' });
      expect(res.statusCode).toEqual(401);
      expect(res.body.success).toBe(false);
    });

    it('should succeed login with valid static credentials and return JWT token', async () => {
      const res = await request(app).post('/api/auth/login').send({
        email: env.staticUser.email,
        password: env.staticUser.password,
      });

      expect(res.statusCode).toEqual(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data).toHaveProperty('token');
      expect(res.body.data.user.email).toBe(env.staticUser.email);
    });

    it('should access /api/auth/me when valid Bearer token provided', async () => {
      const loginRes = await request(app).post('/api/auth/login').send({
        email: env.staticUser.email,
        password: env.staticUser.password,
      });

      const token = loginRes.body.data.token;

      const meRes = await request(app)
        .get('/api/auth/me')
        .set('Authorization', `Bearer ${token}`);

      expect(meRes.statusCode).toEqual(200);
      expect(meRes.body.success).toBe(true);
      expect(meRes.body.data.user.email).toBe(env.staticUser.email);
    });

    it('should reject /api/auth/me without authorization header', async () => {
      const res = await request(app).get('/api/auth/me');
      expect(res.statusCode).toEqual(401);
      expect(res.body.success).toBe(false);
    });
  });
});
