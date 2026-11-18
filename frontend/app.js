'use strict';

const form = document.querySelector('#task-form');
const list = document.querySelector('#tasks');
const errorMessage = document.querySelector('#error');
const remaining = document.querySelector('#remaining');
const search = document.querySelector('#search');
const filter = document.querySelector('#filter');
const save = document.querySelector('#save');
const cancel = document.querySelector('#cancel');
const retry = document.querySelector('#retry');
const priorities = { low: 'Basse', normal: 'Normale', high: 'Haute' };
let tasks = [];
let editingId = null;
let busy = false;

async function request(path = '', method = 'GET', data) {
    const response = await fetch('/api/tasks' + path, {
        method,
        headers: data === undefined ? {} : { 'Content-Type': 'application/json' },
        body: data === undefined ? undefined : JSON.stringify(data),
    });
    if (response.status === 204) return;
    const result = await response.json();
    if (!response.ok) throw new Error(result.error || 'La requête a échoué.');
    return result;
}

function button(text, action) {
    const element = document.createElement('button');
    element.type = 'button';
    element.textContent = text;
    element.addEventListener('click', action);
    return element;
}

function render() {
    const query = search.value.trim().toLocaleLowerCase('fr');
    const status = filter.value;
    const count = tasks.filter(task => !task.completed).length;
    remaining.textContent = count + (count === 1 ? ' tâche restante' : ' tâches restantes');
    list.replaceChildren();

    const visibleTasks = tasks.filter(task =>
        (status === 'all' || task.completed === (status === 'done')) &&
        task.title.toLocaleLowerCase('fr').includes(query)
    );
    for (const task of visibleTasks) {
        const row = document.createElement('li');
        row.classList.toggle('done', task.completed);
        const label = document.createElement('label');
        const checkbox = document.createElement('input');
        checkbox.type = 'checkbox';
        checkbox.checked = task.completed;
        checkbox.addEventListener('change', () => run(async () => {
            const updated = await request('/' + task.id, 'PUT', { ...task, completed: checkbox.checked });
            tasks = tasks.map(current => current.id === updated.id ? updated : current);
        }));
        const title = document.createElement('span');
        title.textContent = task.title;
        label.append(checkbox, title);
        const details = document.createElement('small');
        details.textContent = 'Priorité ' + priorities[task.priority] + (task.due_date ? ' · ' + task.due_date : '');
        row.append(label, details, button('Modifier', () => edit(task)), button('Supprimer', () => run(async () => {
            await request('/' + task.id, 'DELETE');
            tasks = tasks.filter(current => current.id !== task.id);
            if (editingId === task.id) edit();
        })));
        list.append(row);
    }
    if (visibleTasks.length === 0) {
        const empty = document.createElement('li');
        empty.textContent = 'Aucune tâche à afficher.';
        list.append(empty);
    }
}

function edit(task) {
    editingId = task?.id ?? null;
    form.elements.title.value = task?.title ?? '';
    form.elements.priority.value = task?.priority ?? 'normal';
    form.elements.due_date.value = task?.due_date ?? '';
    save.textContent = task ? 'Enregistrer' : 'Ajouter';
    cancel.hidden = !task;
    form.elements.title.focus();
}

async function run(action) {
    if (busy) return;
    busy = true;
    errorMessage.hidden = true;
    const controls = document.querySelectorAll('button, input, select');
    controls.forEach(control => { control.disabled = true; });
    try {
        await action();
    } catch (error) {
        errorMessage.hidden = false;
        errorMessage.textContent = error instanceof SyntaxError || error instanceof TypeError
            ? 'Connexion au serveur impossible. Réessaie.'
            : error.message;
    } finally {
        busy = false;
        controls.forEach(control => { control.disabled = false; });
        render();
    }
}

function loadTasks() {
    retry.hidden = false;
    return run(async () => {
        tasks = await request();
        retry.hidden = true;
    });
}

form.addEventListener('submit', event => {
    event.preventDefault();
    const data = Object.fromEntries(new FormData(form));
    data.due_date ||= null;
    const current = tasks.find(task => task.id === editingId);
    data.completed = current?.completed ?? false;
    run(async () => {
        const result = await request(current ? '/' + current.id : '', current ? 'PUT' : 'POST', data);
        tasks = current ? tasks.map(task => task.id === result.id ? result : task) : [result, ...tasks];
        edit();
    });
});
cancel.addEventListener('click', () => edit());
search.addEventListener('input', render);
filter.addEventListener('change', render);
retry.addEventListener('click', loadTasks);
loadTasks();
