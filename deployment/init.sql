-- Database initialization script for Hydration App
-- Creates tables, indexes, and initial data

-- Create database if it doesn't exist
CREATE DATABASE IF NOT EXISTS hydration_app;

-- Use the database
\c hydration_app;

-- Create users table
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);

-- Create health_metrics table
CREATE TABLE IF NOT EXISTS health_metrics (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    metric_type VARCHAR(50) NOT NULL,
    value DECIMAL(10,2) NOT NULL,
    unit VARCHAR(20) NOT NULL,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    device_id VARCHAR(100),
    confidence DECIMAL(3,2) DEFAULT 1.0
);

-- Create hydration_logs table
CREATE TABLE IF NOT EXISTS hydration_logs (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    amount_ml INTEGER NOT NULL,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    source VARCHAR(50) DEFAULT 'manual',
    notes TEXT
);

-- Create ai_predictions table
CREATE TABLE IF NOT EXISTS ai_predictions (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    prediction_type VARCHAR(50) NOT NULL,
    risk_level VARCHAR(20) NOT NULL,
    confidence DECIMAL(3,2) NOT NULL,
    factors JSONB,
    recommendation TEXT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create challenges table
CREATE TABLE IF NOT EXISTS challenges (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    type VARCHAR(50) NOT NULL,
    target_value INTEGER,
    unit VARCHAR(20),
    duration_days INTEGER,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create user_challenges table
CREATE TABLE IF NOT EXISTS user_challenges (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    challenge_id INTEGER REFERENCES challenges(id),
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP,
    progress INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE
);

-- Create achievements table
CREATE TABLE IF NOT EXISTS achievements (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    icon VARCHAR(50),
    category VARCHAR(50),
    points INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE
);

-- Create user_achievements table
CREATE TABLE IF NOT EXISTS user_achievements (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    achievement_id INTEGER REFERENCES achievements(id),
    earned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    points_earned INTEGER DEFAULT 0
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_health_metrics_user_timestamp ON health_metrics(user_id, timestamp);
CREATE INDEX IF NOT EXISTS idx_hydration_logs_user_timestamp ON hydration_logs(user_id, timestamp);
CREATE INDEX IF NOT EXISTS idx_ai_predictions_user_timestamp ON ai_predictions(user_id, timestamp);
CREATE INDEX IF NOT EXISTS idx_user_challenges_user_active ON user_challenges(user_id, is_active);

-- Insert sample challenges
INSERT INTO challenges (name, description, type, target_value, unit, duration_days) VALUES
('Daily Hydration Goal', 'Drink 8 glasses of water per day', 'hydration', 2000, 'ml', 30),
('Weekly Activity Goal', 'Complete 150 minutes of exercise', 'activity', 150, 'minutes', 7),
('Sleep Consistency', 'Maintain consistent sleep schedule', 'sleep', 8, 'hours', 14),
('Stress Management', 'Practice mindfulness daily', 'wellness', 10, 'minutes', 21)
ON CONFLICT DO NOTHING;

-- Insert sample achievements
INSERT INTO achievements (name, description, icon, category, points) VALUES
('First Drop', 'Log your first hydration entry', 'drop.fill', 'hydration', 10),
('Hydration Hero', 'Drink 2L of water for 7 days straight', 'trophy.fill', 'hydration', 100),
('Early Bird', 'Log hydration before 8 AM', 'sunrise.fill', 'timing', 25),
('Consistency King', 'Log data for 30 days straight', 'calendar.fill', 'consistency', 200),
('Health Guru', 'Complete all weekly challenges', 'star.fill', 'achievement', 150)
ON CONFLICT DO NOTHING;

-- Create views for analytics
CREATE OR REPLACE VIEW user_hydration_summary AS
SELECT 
    u.id as user_id,
    u.username,
    COALESCE(SUM(hl.amount_ml), 0) as total_ml_today,
    COUNT(hl.id) as entries_today,
    AVG(hl.amount_ml) as avg_amount_per_entry
FROM users u
LEFT JOIN hydration_logs hl ON u.id = hl.user_id 
    AND DATE(hl.timestamp) = CURRENT_DATE
GROUP BY u.id, u.username;

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for updated_at
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Grant permissions
GRANT ALL PRIVILEGES ON DATABASE hydration_app TO hydration_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO hydration_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO hydration_user;
