const inGame = typeof GetParentResourceName === 'function';
const resourceName = inGame ? GetParentResourceName() : 'UC-Diabetes';

const $ = (id) => document.getElementById(id);
const monitor = $('monitor');

const TITLES = { testing: 'Home', home: 'Home', history: 'History', info: 'Info', help: 'Help' };
const STATUS_TEXT = { low: 'Low', target: 'In Target', high: 'High' };
const HINTS = {
    low: 'Take an energy tablet',
    target: '',
    high: 'Use your insulin pen',
};
const TYPE_LABELS = { type1: 'Type 1', type2: 'Type 2', none: 'None' };

let testDuration = 5;
let testTimer = null;
let busy = false;

async function post(name, data = {}) {
    if (!inGame) return null;
    try {
        const res = await fetch(`https://${resourceName}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data),
        });
        return await res.json();
    } catch {
        return null;
    }
}

function fitToScreen() {
    // designed against a 1080p screen
    monitor.style.setProperty('--scale', Math.max(window.innerHeight / 1080, 0.5));
}

function showView(name) {
    document.querySelectorAll('.view').forEach((v) => v.classList.toggle('active', v.dataset.view === name));
    document.querySelectorAll('.bottombar [data-nav]').forEach((b) => b.classList.toggle('active', b.dataset.nav === name));
    $('title').textContent = TITLES[name] || 'Home';
}

// point on the quadratic arc M10 36 Q108 2 206 36
function arcPoint(t) {
    const u = 1 - t;
    return {
        x: u * u * 10 + 2 * u * t * 108 + t * t * 206,
        y: u * u * 36 + 2 * u * t * 2 + t * t * 36,
    };
}

function renderReading(r) {
    const status = r.status || 'target';

    $('value').textContent = r.value;
    $('unit').textContent = r.unit;
    $('bubble').className = `bubble ${status}`;
    $('status').className = `status ${status}`;
    $('status').textContent = STATUS_TEXT[status];
    $('hint').textContent = HINTS[status];

    const p = arcPoint(Math.min(Math.max(r.position, 0), 1));
    $('marker').setAttribute('cx', p.x.toFixed(1));
    $('marker').setAttribute('cy', p.y.toFixed(1));
}

function renderHistory(history) {
    const list = $('historyList');
    list.innerHTML = '';

    if (!history || history.length === 0) {
        list.innerHTML = '<li class="empty">No readings yet</li>';
        return;
    }

    for (const r of history) {
        const li = document.createElement('li');
        li.innerHTML = `
            <span class="dot ${r.status}"></span>
            <span class="time"></span>
            <span class="label"></span>
            <span class="reading"></span>`;
        li.querySelector('.time').textContent = r.time;
        li.querySelector('.label').textContent = STATUS_TEXT[r.status];
        li.querySelector('.reading').textContent = `${r.value} ${r.unit}`;
        list.appendChild(li);
    }
}

function renderInfo(info) {
    if (!info) return;
    $('infoType').textContent = TYPE_LABELS[info.type] || info.type;
    $('infoRange').textContent = `${info.targetLow} – ${info.targetHigh} ${info.unit}`;
    $('infoUnit').textContent = info.unit;
}

// Mimics a real meter: count down, then beep and show the result.
function runTest(reading, history) {
    clearInterval(testTimer);
    busy = true;
    showView('testing');

    let remaining = testDuration;
    $('countdown').textContent = remaining;

    testTimer = setInterval(() => {
        remaining -= 1;
        if (remaining > 0) {
            $('countdown').textContent = remaining;
            return;
        }
        clearInterval(testTimer);
        busy = false;
        renderReading(reading);
        renderHistory(history);
        showView('home');
        post('beep');
    }, 1000);
}

function open(data) {
    testDuration = data.testDuration ?? 5;
    $('clock').textContent = data.clock;
    renderInfo(data.info);
    fitToScreen();
    monitor.classList.remove('hidden');
    runTest(data.reading, data.history);
}

function close() {
    clearInterval(testTimer);
    busy = false;
    monitor.classList.add('hidden');
}

window.addEventListener('message', ({ data }) => {
    switch (data.action) {
        case 'open': return open(data);
        case 'close': return close();
        case 'clock': $('clock').textContent = data.clock; return;
    }
});

document.querySelectorAll('[data-nav]').forEach((btn) => {
    btn.addEventListener('click', () => {
        if (!busy) showView(btn.dataset.nav);
    });
});

$('measureBtn').addEventListener('click', async () => {
    if (busy) return;
    const data = await post('measure');
    if (data && data.reading) runTest(data.reading, data.history);
});

$('homeBtn').addEventListener('click', () => post('close'));

document.addEventListener('keyup', (e) => {
    if (e.key === 'Escape' || e.key === 'Backspace') post('close');
});

window.addEventListener('resize', fitToScreen);

// Browser preview outside of FiveM
if (!inGame) {
    document.body.classList.add('preview');
    const sample = { value: '66', unit: 'mg/dL', status: 'target', position: 0.55, time: '2:45 PM' };
    open({
        clock: '2:45',
        testDuration: 1,
        reading: sample,
        history: [sample, { value: '62', unit: 'mg/dL', status: 'low', position: 0.18, time: '1:10 PM' }],
        info: { type: 'type1', unit: 'mg/dL', targetLow: '70', targetHigh: '180' },
    });
}
