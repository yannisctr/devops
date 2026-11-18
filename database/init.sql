CREATE TABLE IF NOT EXISTS tasks (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(160) NOT NULL,
    completed BOOLEAN NOT NULL DEFAULT FALSE,
    priority ENUM('low', 'normal', 'high') NOT NULL DEFAULT 'normal',
    due_date DATE NULL
) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
