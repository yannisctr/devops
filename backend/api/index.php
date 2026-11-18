<?php
declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');

function respond(int $status, ?array $data = null): never
{
    http_response_code($status);
    if ($data !== null) {
        echo json_encode($data, JSON_THROW_ON_ERROR);
    }
    exit;
}

function task(array $row): array
{
    $row['completed'] = (bool) $row['completed'];
    return $row;
}

function readInput(): array
{
    if (strtolower(trim(explode(';', $_SERVER['CONTENT_TYPE'] ?? '')[0])) !== 'application/json') {
        respond(415, ['error' => 'Le corps doit être en JSON.']);
    }
    $raw = file_get_contents('php://input', false, null, 0, 8193);
    if (strlen($raw) > 8192) {
        respond(413, ['error' => 'Requête trop volumineuse.']);
    }
    try {
        $input = json_decode($raw, false, 32, JSON_THROW_ON_ERROR);
    } catch (JsonException) {
        respond(400, ['error' => 'JSON invalide.']);
    }
    if (!$input instanceof stdClass) {
        respond(400, ['error' => 'Un objet JSON est attendu.']);
    }

    $title = is_string($input->title ?? null) ? trim($input->title) : '';
    $completed = $input->completed ?? false;
    $priority = $input->priority ?? 'normal';
    $dueDate = $input->due_date ?? null;
    if (!preg_match('/^[^\p{Cc}]{1,160}$/uD', $title) ||
        !is_bool($completed) || !in_array($priority, ['low', 'normal', 'high'], true)) {
        respond(422, ['error' => 'Titre, statut ou priorité invalide.']);
    }
    if ($dueDate !== null && (!is_string($dueDate) ||
        !preg_match('/^[1-9][0-9]{3}-[0-9]{2}-[0-9]{2}$/D', $dueDate) ||
        !checkdate((int) substr($dueDate, 5, 2), (int) substr($dueDate, 8, 2), (int) substr($dueDate, 0, 4)))) {
        respond(422, ['error' => 'Date d’échéance invalide.']);
    }
    return [$title, (int) $completed, $priority, $dueDate];
}

$path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
$method = $_SERVER['REQUEST_METHOD'];
$collection = $path === '/api/tasks';
$health = $path === '/api/health' || $path === '/api/live';
$item = is_string($path) && preg_match('~^/api/tasks/([1-9][0-9]{0,9})$~D', $path, $matches);
if (!$collection && !$health && !$item) {
    respond(404, ['error' => 'Ressource inconnue.']);
}
$allowed = $collection ? ['GET', 'POST'] : ($health ? ['GET'] : ['PUT', 'DELETE']);
if (!in_array($method, $allowed, true)) {
    header('Allow: ' . implode(', ', $allowed));
    respond(405, ['error' => 'Méthode non autorisée.']);
}
if ($path === '/api/live') {
    respond(200, ['status' => 'ok']);
}
$values = in_array($method, ['POST', 'PUT'], true) ? readInput() : [];
try {
    $db = new PDO(
        sprintf('mysql:host=%s;dbname=%s;charset=utf8mb4', getenv('DB_HOST'), getenv('DB_NAME')),
        getenv('DB_USER'),
        getenv('DB_PASSWORD'),
        [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => false,
            PDO::ATTR_TIMEOUT => 3,
        ]
    );
} catch (PDOException $error) {
    error_log('MySQL connection failed (code ' . $error->getCode() . ')');
    respond(503, ['error' => 'Base de données indisponible.']);
}
try {
    if ($health) {
        $db->query('SELECT id FROM tasks LIMIT 1');
        respond(200, ['status' => 'ok']);
    }
    if ($method === 'GET') {
        respond(200, array_map('task', $db->query('SELECT * FROM tasks ORDER BY id DESC')->fetchAll()));
    }
    if ($method === 'POST') {
        $db->prepare('INSERT INTO tasks (title, completed, priority, due_date) VALUES (?, ?, ?, ?)')->execute($values);
        $id = (int) $db->lastInsertId();
        header('Location: /api/tasks/' . $id);
        respond(201, task(array_combine(['title', 'completed', 'priority', 'due_date'], $values) + ['id' => $id]));
    }
    $id = (int) $matches[1];
    if ($method === 'DELETE') {
        $delete = $db->prepare('DELETE FROM tasks WHERE id = ?');
        $delete->execute([$id]);
        if ($delete->rowCount() === 0) {
            respond(404, ['error' => 'Tâche introuvable.']);
        }
        respond(204);
    }
    $db->beginTransaction();
    $select = $db->prepare('SELECT id FROM tasks WHERE id = ? FOR UPDATE');
    $select->execute([$id]);
    if (!$select->fetch()) {
        $db->rollBack();
        respond(404, ['error' => 'Tâche introuvable.']);
    }
    $db->prepare('UPDATE tasks SET title = ?, completed = ?, priority = ?, due_date = ? WHERE id = ?')
        ->execute([...$values, $id]);
    $db->commit();
    respond(200, task(array_combine(['title', 'completed', 'priority', 'due_date'], $values) + ['id' => $id]));
} catch (PDOException $error) {
    error_log('MySQL query failed (code ' . $error->getCode() . ')');
    respond($health ? 503 : 500, ['error' => 'Erreur de base de données.']);
}
