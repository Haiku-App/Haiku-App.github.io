const TASKS_KEY = "haiku.web.tasks.v2";
const TODOS_KEY = "haiku.web.todos.v1";
const DEVICE_KEY = "haiku.web.device.v1";
const BROWSER_KEY = "haiku.web.browserId.v1";

const categories = [
  { id: "deep-work", name: "Deep Work", color: "#D9C794" },
  { id: "meeting", name: "Meeting", color: "#BF8C73" },
  { id: "break", name: "Break", color: "#738059" },
  { id: "study", name: "Study", color: "#6AA3BE" },
  { id: "personal", name: "Personal", color: "#7A9E85" },
  { id: "routine", name: "Routine", color: "#8C82A8" }
];

const quotes = [
  "\"A year from now you will wish you had started today.\"",
  "\"How we spend our days is, of course, how we spend our lives.\"",
  "\"The bad news is time flies. The good news is you're the pilot.\"",
  "\"The future depends on what you do today.\"",
  "\"You are what you do, not what you say you'll do.\""
];

const iconPaths = {
  clock: '<circle cx="12" cy="12" r="8"></circle><path d="M12 7v5l-3 2"></path>',
  calendar: '<path d="M8 2v4"></path><path d="M16 2v4"></path><rect x="3" y="4" width="18" height="18" rx="2"></rect><path d="M3 10h18"></path>',
  list: '<path d="M8 6h13"></path><path d="M8 12h13"></path><path d="M8 18h13"></path><path d="M3 6h.01"></path><path d="M3 12h.01"></path><path d="M3 18h.01"></path>',
  pie: '<path d="M12 2v10h10"></path><path d="M20.49 15a9 9 0 1 1-11.48-11.5"></path>',
  person: '<path d="M20 21a8 8 0 0 0-16 0"></path><circle cx="12" cy="7" r="4"></circle>',
  plus: '<path d="M12 5v14"></path><path d="M5 12h14"></path>',
  "zoom-in": '<circle cx="10.5" cy="10.5" r="6.5"></circle><path d="M10.5 8v5"></path><path d="M8 10.5h5"></path><path d="m16 16 5 5"></path>',
  "chevron-left": '<path d="m15 18-6-6 6-6"></path>',
  "chevron-right": '<path d="m9 18 6-6-6-6"></path>',
  refresh: '<path d="M21 12a9 9 0 0 1-15.14 6.64"></path><path d="M3 12A9 9 0 0 1 18.14 5.36"></path><path d="M21 3v6h-6"></path><path d="M3 21v-6h6"></path>',
  monitor: '<rect x="3" y="4" width="18" height="13" rx="2"></rect><path d="M8 21h8"></path><path d="M12 17v4"></path>',
  unlink: '<path d="M10 13a5 5 0 0 0 7.54.54l2-2a5 5 0 0 0-7.07-7.07l-1.13 1.13"></path><path d="M14 11a5 5 0 0 0-7.54-.54l-2 2a5 5 0 0 0 7.07 7.07l1.13-1.13"></path><path d="m3 3 18 18"></path>',
  leaf: '<path d="M11 20A7 7 0 0 1 4 13c0-5 4-8 9-9 4 4 7 8 7 12a6 6 0 0 1-9 5"></path><path d="M8 14c4 0 7 2 9 5"></path>',
  trash: '<path d="M3 6h18"></path><path d="M8 6V4h8v2"></path><path d="m6 6 1 16h10l1-16"></path>',
  check: '<path d="m20 6-11 11-5-5"></path>'
};

const els = {
  weekdayLabel: document.querySelector("#weekdayLabel"),
  dateLabel: document.querySelector("#dateLabel"),
  dateButton: document.querySelector("#dateButton"),
  datePicker: document.querySelector("#datePicker"),
  prevDay: document.querySelector("#prevDay"),
  nextDay: document.querySelector("#nextDay"),
  quickAdd: document.querySelector("#quickAdd"),
  zoomClock: document.querySelector("#zoomClock"),
  dailyQuote: document.querySelector("#dailyQuote"),
  taskList: document.querySelector("#taskList"),
  clockSvg: document.querySelector("#clockSvg"),
  taskDialog: document.querySelector("#taskDialog"),
  closeTaskDialog: document.querySelector("#closeTaskDialog"),
  taskForm: document.querySelector("#taskForm"),
  taskTitle: document.querySelector("#taskTitle"),
  taskDate: document.querySelector("#taskDate"),
  taskStart: document.querySelector("#taskStart"),
  taskEnd: document.querySelector("#taskEnd"),
  taskCategory: document.querySelector("#taskCategory"),
  colorSwatches: document.querySelector("#colorSwatches"),
  todoForm: document.querySelector("#todoForm"),
  todoInput: document.querySelector("#todoInput"),
  routineList: document.querySelector("#routineList"),
  upcomingList: document.querySelector("#upcomingList"),
  insightBars: document.querySelector("#insightBars"),
  insightStats: document.querySelector("#insightStats"),
  openPairing: document.querySelector("#openPairing"),
  unlinkDevice: document.querySelector("#unlinkDevice"),
  syncNow: document.querySelector("#syncNow"),
  deviceTitle: document.querySelector("#deviceTitle"),
  deviceStatus: document.querySelector("#deviceStatus"),
  pairingDialog: document.querySelector("#pairingDialog"),
  closePairing: document.querySelector("#closePairing"),
  qrCode: document.querySelector("#qrCode"),
  pairCode: document.querySelector("#pairCode"),
  pairExpiry: document.querySelector("#pairExpiry"),
  browserName: document.querySelector("#browserName"),
  refreshPairCode: document.querySelector("#refreshPairCode"),
  simulatePairing: document.querySelector("#simulatePairing"),
  toast: document.querySelector("#toast")
};

const SyncClient = {
  apiBase: window.HAIKU_SYNC_API_BASE || "",

  async pollPairing(pairing) {
    if (!this.apiBase) return null;
    const response = await fetch(`${this.apiBase}/pairings/${pairing.code}`, {
      headers: { "X-Haiku-Browser-Id": pairing.browserId }
    });
    return response.ok ? response.json() : null;
  },

  async pushSnapshot(tasks, device) {
    if (!this.apiBase || !device?.token) return { mode: "local" };
    const response = await fetch(`${this.apiBase}/sync/tasks`, {
      method: "PUT",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${device.token}`
      },
      body: JSON.stringify({
        schemaVersion: 1,
        modifiedAt: new Date().toISOString(),
        tasks
      })
    });
    if (!response.ok) throw new Error("Sync failed");
    return response.json();
  }
};

const state = {
  selectedDate: startOfDay(new Date()),
  selectedColor: categories[0].color,
  selectedCategory: categories[0].id,
  tasks: loadJson(TASKS_KEY, null) || seedTasks(),
  todos: loadJson(TODOS_KEY, null) || seedTodos(),
  device: loadJson(DEVICE_KEY, null),
  view: "day",
  zoomed: false,
  pairing: null,
  expiryTimer: null,
  pollingTimer: null,
  toastTimer: null
};

hydrateIcons();
init();

function init() {
  saveTasks();
  saveTodos();
  bindEvents();
  renderCategoryOptions();
  setDefaultFormTimes();
  render();
  window.setInterval(renderClock, 1000);
}

function bindEvents() {
  document.querySelectorAll(".tab-item").forEach((button) => {
    button.addEventListener("click", () => {
      state.view = button.dataset.view;
      render();
    });
  });

  els.prevDay.addEventListener("click", () => changeDate(-1));
  els.nextDay.addEventListener("click", () => changeDate(1));
  els.dateButton.addEventListener("click", () => {
    if (typeof els.datePicker.showPicker === "function") {
      els.datePicker.showPicker();
    } else {
      els.datePicker.click();
    }
  });
  els.datePicker.addEventListener("change", () => {
    state.selectedDate = fromDateKey(els.datePicker.value);
    render();
  });

  els.zoomClock.addEventListener("click", () => {
    state.zoomed = !state.zoomed;
    document.querySelector(".clock-stage").style.transform = state.zoomed ? "scale(1.08)" : "scale(1)";
    renderClock();
  });

  els.quickAdd.addEventListener("click", openTaskDialog);
  els.closeTaskDialog.addEventListener("click", () => els.taskDialog.close());
  els.taskForm.addEventListener("submit", addTaskFromForm);
  els.taskCategory.addEventListener("change", () => {
    state.selectedCategory = els.taskCategory.value;
    state.selectedColor = getCategory(state.selectedCategory).color;
    renderSwatches();
  });
  els.colorSwatches.addEventListener("click", (event) => {
    const swatch = event.target.closest("[data-color]");
    if (!swatch) return;
    state.selectedColor = swatch.dataset.color;
    renderSwatches();
  });
  els.taskList.addEventListener("click", handleTaskAction);

  els.todoForm.addEventListener("submit", (event) => {
    event.preventDefault();
    const title = els.todoInput.value.trim();
    if (!title) return;
    state.todos.push({ id: crypto.randomUUID(), title, isCompleted: false });
    els.todoInput.value = "";
    saveTodos();
    renderRoutines();
    toast("Added");
  });
  els.routineList.addEventListener("click", (event) => {
    const row = event.target.closest("[data-todo-id]");
    if (!row) return;
    const todo = state.todos.find((item) => item.id === row.dataset.todoId);
    if (!todo) return;
    todo.isCompleted = !todo.isCompleted;
    saveTodos();
    renderRoutines();
  });

  els.openPairing.addEventListener("click", openPairingDialog);
  els.closePairing.addEventListener("click", closePairingDialog);
  els.refreshPairCode.addEventListener("click", () => {
    state.pairing = createPairing();
    renderPairing();
    startPairingTimers();
  });
  els.simulatePairing.addEventListener("click", confirmPairingLocally);
  els.unlinkDevice.addEventListener("click", unlinkDevice);
  els.syncNow.addEventListener("click", () => syncNow(true));
}

function render() {
  renderNavigation();
  renderHeader();
  renderDevice();
  renderTaskList();
  renderClock();
  renderUpcoming();
  renderRoutines();
  renderInsights();
}

function renderNavigation() {
  document.querySelectorAll(".tab-item").forEach((button) => {
    button.classList.toggle("is-active", button.dataset.view === state.view);
  });
  document.querySelectorAll(".view").forEach((view) => {
    view.classList.remove("is-visible");
  });
  document.querySelector(`#${state.view}View`)?.classList.add("is-visible");
}

function renderHeader() {
  const selected = state.selectedDate;
  els.datePicker.value = dateKey(selected);
  els.taskDate.value = dateKey(selected);
  els.weekdayLabel.textContent = relativeDayLabel(selected);
  els.dateLabel.textContent = selected.toLocaleDateString(undefined, { month: "long", day: "numeric" });
  els.dailyQuote.textContent = quoteForDate(selected);
}

function renderDevice() {
  if (state.device) {
    els.deviceTitle.textContent = state.device.name || "Linked Computer";
    els.deviceStatus.textContent = state.device.lastSyncedAt
      ? `Synced ${timeAgo(new Date(state.device.lastSyncedAt))}`
      : "Ready to sync";
    els.unlinkDevice.classList.remove("hidden");
  } else {
    els.deviceTitle.textContent = "Link a Computer";
    els.deviceStatus.textContent = "Pair this browser once.";
    els.unlinkDevice.classList.add("hidden");
  }
}

function renderTaskList() {
  const tasks = getTasksForDate(state.selectedDate);
  if (!tasks.length) {
    els.taskList.innerHTML = '<div class="empty-state">No tasks scheduled</div>';
    return;
  }

  els.taskList.innerHTML = tasks.map((task) => `
    <article class="ios-task-row${task.isCompleted ? " is-complete" : ""}" data-task-id="${task.id}">
      <div class="task-times">
        <strong>${minutesToDisplay(task.startMinutes)}</strong>
        <span>${minutesToDisplay(task.endMinutes)}</span>
      </div>
      <div class="task-divider"></div>
      <div class="task-title-line">
        <span class="leaf-icon" style="--task-color:${task.color}" data-icon="leaf"></span>
        <p class="task-name">${escapeHtml(task.title)}</p>
      </div>
      <button class="task-delete" type="button" data-action="delete-task" data-task-id="${task.id}" aria-label="Delete ${escapeHtml(task.title)}">
        <span data-icon="trash"></span>
      </button>
    </article>
  `).join("");
  hydrateIcons(els.taskList);
}

function renderClock() {
  const svg = els.clockSvg;
  svg.innerHTML = "";

  const cx = 210;
  const cy = 210;
  const faceR = 122;
  const pmR = 178;
  const amR = 148;
  const ringWidth = 23;
  const tasks = getTasksForDate(state.selectedDate);

  svg.appendChild(svgEl("circle", { class: "track-ring pm", cx, cy, r: pmR }));
  svg.appendChild(svgEl("circle", { class: "track-ring am", cx, cy, r: amR }));

  tasks.forEach((task) => {
    getTwelveHourFragments(task).forEach((fragment) => {
      const path = svgEl("path", {
        class: `task-arc${task.isCompleted ? " is-complete" : ""}`,
        d: describeArc(cx, cy, fragment.isAM ? amR : pmR, minutesTo12Angle(fragment.start), minutesTo12Angle(fragment.end)),
        stroke: task.color,
        "stroke-width": ringWidth
      });
      svg.appendChild(path);
    });
  });

  svg.appendChild(svgEl("circle", { class: "clock-face", cx, cy, r: faceR }));
  svg.appendChild(svgEl("circle", { class: "inner-bezel", cx, cy, r: faceR + 7 }));

  addRingLabel(svg, cx - 2, cy - pmR + 14, "PM", 24);
  addRingLabel(svg, cx - 2, cy - amR + 17, "AM", 22);
  drawTicks(svg, cx, cy, faceR);
  drawNumbers(svg, cx, cy, faceR);
  drawHands(svg, cx, cy, faceR);
  drawActiveStatus(svg, cx, cy, tasks);
}

function addRingLabel(svg, x, y, text, size) {
  const label = svgEl("text", { class: "ring-label", x, y, "font-size": size });
  label.textContent = text;
  svg.appendChild(label);
}

function drawTicks(svg, cx, cy, radius) {
  for (let i = 0; i < 60; i += 1) {
    const isHour = i % 5 === 0;
    const angle = i * 6;
    const start = polarPoint(cx, cy, radius - (isHour ? 15 : 9), angle);
    const end = polarPoint(cx, cy, radius - 3, angle);
    svg.appendChild(svgEl("line", {
      class: "tick",
      x1: start.x,
      y1: start.y,
      x2: end.x,
      y2: end.y,
      "stroke-width": isHour ? 1.8 : 0.8,
      opacity: isHour ? 0.72 : 0.24
    }));
  }
}

function drawNumbers(svg, cx, cy, radius) {
  [12, 3, 6, 9].forEach((hour) => {
    const angle = hour === 12 ? 0 : hour * 30;
    const pos = polarPoint(cx, cy, radius * 0.7, angle);
    const text = svgEl("text", {
      class: "clock-number",
      x: pos.x,
      y: pos.y,
      "font-size": 31
    });
    text.textContent = String(hour);
    svg.appendChild(text);
  });
}

function drawHands(svg, cx, cy, radius) {
  const now = new Date();
  const hour = now.getHours() % 12;
  const minute = now.getMinutes();
  const second = now.getSeconds();
  const hourAngle = (hour + minute / 60) * 30;
  const minuteAngle = (minute + second / 60) * 6;
  const secondAngle = second * 6;
  const hourEnd = polarPoint(cx, cy, radius * 0.48, hourAngle);
  const minuteEnd = polarPoint(cx, cy, radius * 0.82, minuteAngle);
  const secondEnd = polarPoint(cx, cy, radius * 0.74, secondAngle);
  const secondBack = polarPoint(cx, cy, radius * 0.42, secondAngle + 180);

  svg.appendChild(svgEl("line", { class: "hand", x1: cx, y1: cy, x2: hourEnd.x, y2: hourEnd.y, "stroke-width": 7 }));
  svg.appendChild(svgEl("line", { class: "hand", x1: cx, y1: cy, x2: minuteEnd.x, y2: minuteEnd.y, "stroke-width": 5 }));
  svg.appendChild(svgEl("line", { class: "second-hand", x1: secondBack.x, y1: secondBack.y, x2: secondEnd.x, y2: secondEnd.y }));
  svg.appendChild(svgEl("circle", { class: "center-pin", cx, cy, r: 8 }));
}

function drawActiveStatus(svg, cx, cy, tasks) {
  if (!isSameDay(state.selectedDate, new Date())) return;
  const now = new Date();
  const currentMinute = now.getHours() * 60 + now.getMinutes();
  const active = tasks.find((task) => !task.isCompleted && currentMinute >= task.startMinutes && currentMinute < normalizedEnd(task));
  if (!active) return;
  const remaining = Math.max(0, normalizedEnd(active) - currentMinute);
  const text = svgEl("text", {
    class: "active-time",
    x: cx,
    y: cy + 70,
    fill: active.color
  });
  text.textContent = `${remaining} min left`;
  svg.appendChild(text);
}

function renderUpcoming() {
  const days = Array.from({ length: 7 }, (_, index) => addDays(state.selectedDate, index));
  els.upcomingList.innerHTML = days.map((day) => {
    const tasks = getTasksForDate(day);
    return `
      <section class="week-day">
        <div class="week-date">${day.toLocaleDateString(undefined, { weekday: "short", day: "numeric" })}</div>
        <div class="week-items">
          ${tasks.length ? tasks.map((task) => `
            <div class="week-task">
              <span class="week-dot" style="--task-color:${task.color}"></span>
              <span>${escapeHtml(task.title)}</span>
            </div>
          `).join("") : '<div class="week-task"><span class="week-dot"></span><span>No tasks</span></div>'}
        </div>
      </section>
    `;
  }).join("");
}

function renderRoutines() {
  els.routineList.innerHTML = state.todos.map((todo) => `
    <button class="brain-row${todo.isCompleted ? " is-complete" : ""}" type="button" data-todo-id="${todo.id}">
      <span class="brain-check"></span>
      <p>${escapeHtml(todo.title)}</p>
    </button>
  `).join("");
}

function renderInsights() {
  const weekDays = Array.from({ length: 7 }, (_, index) => addDays(state.selectedDate, index));
  const weekTasks = state.tasks.filter((task) => weekDays.some((day) => dateKey(day) === task.dateKey));
  const totalMinutes = weekTasks.reduce((sum, task) => sum + durationMinutes(task), 0);
  const totals = categories.map((category) => ({
    ...category,
    minutes: weekTasks
      .filter((task) => task.categoryId === category.id)
      .reduce((sum, task) => sum + durationMinutes(task), 0)
  }));
  const top = totals.slice().sort((a, b) => b.minutes - a.minutes)[0] || categories[0];

  els.insightStats.innerHTML = `
    <div class="stat-tile"><span data-icon="clock"></span><strong>${formatHours(totalMinutes)}</strong><span>Total Time</span></div>
    <div class="stat-tile"><span data-icon="pie"></span><strong>${escapeHtml(top.name)}</strong><span>Top Activity</span></div>
  `;
  hydrateIcons(els.insightStats);

  const hourTotals = Array.from({ length: 24 }, () => 0);
  weekTasks.forEach((task) => {
    const startHour = Math.floor(task.startMinutes / 60);
    const endHour = Math.max(startHour + 1, Math.ceil(normalizedEnd(task) / 60));
    for (let hour = startHour; hour < endHour; hour += 1) {
      hourTotals[hour % 24] += 1;
    }
  });
  const max = Math.max(1, ...hourTotals);
  const peak = hourTotals.indexOf(max);
  document.querySelector("#insightTitle").textContent = `Your rhythm peaks at ${hourLabel(peak)}`;
  els.insightBars.innerHTML = hourTotals.map((value, index) => `
    <span class="native-bar" style="height:${Math.max(8, (value / max) * 130)}px; --bar-color:${index === peak ? "#D9C794" : "rgba(217, 199, 148, 0.55)"}; --bar-opacity:${value ? 1 : 0.22}"></span>
  `).join("");
}

function renderCategoryOptions() {
  els.taskCategory.innerHTML = categories.map((category) => (
    `<option value="${category.id}">${escapeHtml(category.name)}</option>`
  )).join("");
  els.taskCategory.value = state.selectedCategory;
  renderSwatches();
}

function renderSwatches() {
  els.colorSwatches.innerHTML = categories.map((category) => `
    <button
      class="swatch${category.color === state.selectedColor ? " is-selected" : ""}"
      style="--swatch:${category.color}"
      type="button"
      data-color="${category.color}"
      aria-label="${escapeHtml(category.name)} color">
    </button>
  `).join("");
}

function openTaskDialog() {
  els.taskDate.value = dateKey(state.selectedDate);
  setDefaultFormTimes();
  if (!els.taskDialog.open) els.taskDialog.showModal();
  window.setTimeout(() => els.taskTitle.focus(), 80);
}

function addTaskFromForm(event) {
  event.preventDefault();
  const title = els.taskTitle.value.trim();
  if (!title) return;

  const category = getCategory(els.taskCategory.value);
  const startMinutes = inputToMinutes(els.taskStart.value);
  let endMinutes = inputToMinutes(els.taskEnd.value);
  if (endMinutes === startMinutes) endMinutes = (startMinutes + 60) % 1440;

  state.selectedDate = fromDateKey(els.taskDate.value);
  state.tasks.push({
    id: crypto.randomUUID(),
    dateKey: dateKey(state.selectedDate),
    title,
    startMinutes,
    endMinutes,
    color: state.selectedColor,
    categoryId: category.id,
    categoryName: category.name,
    isCompleted: false,
    repeatFrequency: "never"
  });

  els.taskTitle.value = "";
  saveAndSync("Task added");
  els.taskDialog.close();
}

function handleTaskAction(event) {
  const button = event.target.closest("[data-action]");
  if (!button) return;
  if (button.dataset.action === "delete-task") {
    state.tasks = state.tasks.filter((task) => task.id !== button.dataset.taskId);
    saveAndSync("Task deleted");
  }
}

function changeDate(days) {
  state.selectedDate = addDays(state.selectedDate, days);
  render();
}

function setDefaultFormTimes(anchorMinutes) {
  const now = new Date();
  let start = typeof anchorMinutes === "number"
    ? anchorMinutes
    : Math.ceil((now.getHours() * 60 + now.getMinutes()) / 30) * 30;
  start %= 1440;
  els.taskStart.value = minutesToInput(start);
  els.taskEnd.value = minutesToInput((start + 60) % 1440);
}

function openPairingDialog() {
  state.pairing = createPairing();
  els.browserName.value = state.device?.name || getDefaultBrowserName();
  renderPairing();
  startPairingTimers();
  if (!els.pairingDialog.open) els.pairingDialog.showModal();
}

function closePairingDialog() {
  stopPairingTimers();
  els.pairingDialog.close();
}

function createPairing() {
  const browserId = getBrowserId();
  const code = generatePairCode();
  const expiresAt = Date.now() + 10 * 60 * 1000;
  const origin = window.location.origin === "null" ? "https://haikuclock.app" : window.location.origin;
  return {
    code,
    browserId,
    expiresAt,
    payload: `${origin}/pair?code=${encodeURIComponent(code)}&browser=${encodeURIComponent(browserId)}`
  };
}

function renderPairing() {
  if (!state.pairing) return;
  els.pairCode.textContent = state.pairing.code;
  renderQr(state.pairing.payload);
  renderExpiry();
}

function renderQr(payload) {
  if (typeof qrcode === "function") {
    const qr = qrcode(0, "M");
    qr.addData(payload);
    qr.make();
    els.qrCode.innerHTML = qr.createSvgTag(5, 2);
    return;
  }
  els.qrCode.innerHTML = fallbackQrSvg(payload);
}

function renderExpiry() {
  if (!state.pairing) return;
  const seconds = Math.max(0, Math.floor((state.pairing.expiresAt - Date.now()) / 1000));
  els.pairExpiry.textContent = `Expires in ${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, "0")}`;
  if (seconds <= 0) {
    state.pairing = createPairing();
    renderPairing();
  }
}

function startPairingTimers() {
  stopPairingTimers();
  state.expiryTimer = window.setInterval(renderExpiry, 1000);
  state.pollingTimer = window.setInterval(async () => {
    if (!state.pairing || !SyncClient.apiBase) return;
    const result = await SyncClient.pollPairing(state.pairing);
    if (result?.deviceToken) {
      completePairing(result.deviceToken);
    }
  }, 2500);
}

function stopPairingTimers() {
  if (state.expiryTimer) window.clearInterval(state.expiryTimer);
  if (state.pollingTimer) window.clearInterval(state.pollingTimer);
  state.expiryTimer = null;
  state.pollingTimer = null;
}

function confirmPairingLocally() {
  completePairing(`local_${crypto.randomUUID()}`);
}

function completePairing(token) {
  state.device = {
    name: els.browserName.value.trim() || getDefaultBrowserName(),
    token,
    linkedAt: new Date().toISOString(),
    lastSyncedAt: new Date().toISOString()
  };
  saveDevice();
  closePairingDialog();
  render();
  toast("Browser linked");
}

function unlinkDevice() {
  state.device = null;
  localStorage.removeItem(DEVICE_KEY);
  render();
  toast("Browser unlinked");
}

async function syncNow(showToast) {
  if (!state.device) {
    if (showToast) openPairingDialog();
    return;
  }
  try {
    await SyncClient.pushSnapshot(state.tasks, state.device);
    state.device.lastSyncedAt = new Date().toISOString();
    saveDevice();
    renderDevice();
    if (showToast) toast(SyncClient.apiBase ? "Synced" : "Saved locally");
  } catch {
    if (showToast) toast("Sync failed");
  }
}

function saveAndSync(message) {
  saveTasks();
  render();
  toast(message);
  syncNow(false);
}

function saveTasks() {
  localStorage.setItem(TASKS_KEY, JSON.stringify(sortTasks(state.tasks)));
}

function saveTodos() {
  localStorage.setItem(TODOS_KEY, JSON.stringify(state.todos));
}

function saveDevice() {
  localStorage.setItem(DEVICE_KEY, JSON.stringify(state.device));
}

function seedTasks() {
  const today = dateKey(new Date());
  const tomorrow = dateKey(addDays(new Date(), 1));
  return sortTasks([
    createTask(today, "Physics Lecture", 600, 710, "deep-work"),
    createTask(today, "Chem 2 Lecture", 960, 1155, "meeting"),
    createTask(today, "Study", 1185, 1322, "study"),
    createTask(tomorrow, "Reading sprint", 540, 630, "study")
  ]);
}

function createTask(dayKey, title, startMinutes, endMinutes, categoryId) {
  const category = getCategory(categoryId);
  return {
    id: crypto.randomUUID(),
    dateKey: dayKey,
    title,
    startMinutes,
    endMinutes,
    color: category.color,
    categoryId,
    categoryName: category.name,
    isCompleted: false,
    repeatFrequency: "never"
  };
}

function seedTodos() {
  return [
    { id: crypto.randomUUID(), title: "Email coach about practice", isCompleted: false },
    { id: crypto.randomUUID(), title: "English essay due at 4pm today", isCompleted: false },
    { id: crypto.randomUUID(), title: "8.8 notes due 3/17", isCompleted: false },
    { id: crypto.randomUUID(), title: "Physics study for quiz", isCompleted: false }
  ];
}

function getTasksForDate(date) {
  return sortTasks(state.tasks.filter((task) => task.dateKey === dateKey(date)));
}

function sortTasks(tasks) {
  return [...tasks].sort((a, b) => a.dateKey.localeCompare(b.dateKey) || a.startMinutes - b.startMinutes);
}

function getCategory(id) {
  return categories.find((category) => category.id === id) || categories[0];
}

function getTwelveHourFragments(task) {
  const fragments = [];
  let start = task.startMinutes;
  const end = normalizedEnd(task);
  while (start < end) {
    const periodStart = Math.floor(start / 720) * 720;
    const periodEnd = periodStart + 720;
    const next = Math.min(end, periodEnd);
    const startMod = start - periodStart;
    const endMod = next === periodEnd ? 720 : next - periodStart;
    fragments.push({
      isAM: Math.floor(start / 720) % 2 === 0,
      start: startMod,
      end: endMod
    });
    start = next;
  }
  return fragments;
}

function normalizedEnd(task) {
  return task.endMinutes > task.startMinutes ? task.endMinutes : task.endMinutes + 1440;
}

function durationMinutes(task) {
  return normalizedEnd(task) - task.startMinutes;
}

function formatHours(minutes) {
  return `${(minutes / 60).toFixed(1)}h`;
}

function inputToMinutes(value) {
  const [hours, minutes] = value.split(":").map(Number);
  return hours * 60 + minutes;
}

function minutesToInput(minutes) {
  const normalized = ((minutes % 1440) + 1440) % 1440;
  const hours = Math.floor(normalized / 60);
  const mins = normalized % 60;
  return `${String(hours).padStart(2, "0")}:${String(mins).padStart(2, "0")}`;
}

function minutesToDisplay(minutes) {
  const normalized = ((minutes % 1440) + 1440) % 1440;
  const hours = Math.floor(normalized / 60);
  const mins = normalized % 60;
  const period = hours >= 12 ? "PM" : "AM";
  const hour = hours % 12 || 12;
  return `${hour}:${String(mins).padStart(2, "0")} ${period}`;
}

function hourLabel(hour) {
  const period = hour >= 12 ? "PM" : "AM";
  const value = hour % 12 || 12;
  return `${value} ${period}`;
}

function startOfDay(date) {
  const copy = new Date(date);
  copy.setHours(0, 0, 0, 0);
  return copy;
}

function addDays(date, days) {
  const copy = startOfDay(date);
  copy.setDate(copy.getDate() + days);
  return copy;
}

function dateKey(date) {
  const day = startOfDay(date);
  return [
    day.getFullYear(),
    String(day.getMonth() + 1).padStart(2, "0"),
    String(day.getDate()).padStart(2, "0")
  ].join("-");
}

function fromDateKey(key) {
  const [year, month, day] = key.split("-").map(Number);
  return new Date(year, month - 1, day);
}

function isSameDay(a, b) {
  return dateKey(a) === dateKey(b);
}

function relativeDayLabel(date) {
  const today = startOfDay(new Date());
  const diff = Math.round((startOfDay(date) - today) / 86400000);
  if (diff === 0) return "Today";
  if (diff === 1) return "Tomorrow";
  if (diff === -1) return "Yesterday";
  return date.toLocaleDateString(undefined, { weekday: "long" });
}

function quoteForDate(date) {
  const start = new Date(date.getFullYear(), 0, 0);
  const day = Math.floor((date - start) / 86400000);
  return quotes[day % quotes.length];
}

function minutesTo12Angle(minutes) {
  return (minutes / 720) * 360;
}

function polarPoint(cx, cy, radius, angle) {
  const radians = (angle - 90) * Math.PI / 180;
  return {
    x: cx + radius * Math.cos(radians),
    y: cy + radius * Math.sin(radians)
  };
}

function describeArc(cx, cy, radius, startAngle, endAngle) {
  const start = polarPoint(cx, cy, radius, endAngle);
  const end = polarPoint(cx, cy, radius, startAngle);
  const largeArc = endAngle - startAngle <= 180 ? 0 : 1;
  return `M ${start.x.toFixed(3)} ${start.y.toFixed(3)} A ${radius} ${radius} 0 ${largeArc} 0 ${end.x.toFixed(3)} ${end.y.toFixed(3)}`;
}

function svgEl(name, attrs = {}) {
  const node = document.createElementNS("http://www.w3.org/2000/svg", name);
  Object.entries(attrs).forEach(([key, value]) => node.setAttribute(key, value));
  return node;
}

function hydrateIcons(root = document) {
  root.querySelectorAll("[data-icon]").forEach((node) => {
    const path = iconPaths[node.dataset.icon];
    if (!path) return;
    node.innerHTML = `<svg viewBox="0 0 24 24" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${path}</svg>`;
  });
}

function generatePairCode() {
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  const values = new Uint8Array(6);
  crypto.getRandomValues(values);
  return Array.from(values, (value) => alphabet[value % alphabet.length]).join("");
}

function getBrowserId() {
  let browserId = localStorage.getItem(BROWSER_KEY);
  if (!browserId) {
    browserId = crypto.randomUUID();
    localStorage.setItem(BROWSER_KEY, browserId);
  }
  return browserId;
}

function getDefaultBrowserName() {
  const agent = navigator.userAgent;
  const platform = navigator.platform || "Computer";
  const browser = agent.includes("Edg/") ? "Edge" :
    agent.includes("Chrome/") ? "Chrome" :
    agent.includes("Safari/") ? "Safari" :
    agent.includes("Firefox/") ? "Firefox" :
    "Browser";
  return `${browser} on ${platform}`;
}

function fallbackQrSvg(payload) {
  const grid = 29;
  const cell = 7;
  const size = grid * cell;
  let seed = hashString(payload);
  const cells = [];
  for (let y = 0; y < grid; y += 1) {
    for (let x = 0; x < grid; x += 1) {
      const inFinder = (x < 7 && y < 7) || (x >= grid - 7 && y < 7) || (x < 7 && y >= grid - 7);
      if (inFinder) continue;
      seed = (seed * 1664525 + 1013904223) >>> 0;
      if (seed % 3 === 0) cells.push(`<rect x="${x * cell}" y="${y * cell}" width="${cell}" height="${cell}" fill="#111"/>`);
    }
  }
  const finder = (x, y) => `
    <rect x="${x}" y="${y}" width="${cell * 7}" height="${cell * 7}" fill="#111"/>
    <rect x="${x + cell}" y="${y + cell}" width="${cell * 5}" height="${cell * 5}" fill="#fff"/>
    <rect x="${x + cell * 2}" y="${y + cell * 2}" width="${cell * 3}" height="${cell * 3}" fill="#111"/>
  `;
  return `<svg viewBox="0 0 ${size} ${size}" role="img" aria-label="Pairing code mark"><rect width="${size}" height="${size}" fill="#fff"/>${finder(0, 0)}${finder(size - cell * 7, 0)}${finder(0, size - cell * 7)}${cells.join("")}</svg>`;
}

function hashString(value) {
  let hash = 2166136261;
  for (let index = 0; index < value.length; index += 1) {
    hash ^= value.charCodeAt(index);
    hash = Math.imul(hash, 16777619);
  }
  return hash >>> 0;
}

function loadJson(key, fallback) {
  try {
    const value = localStorage.getItem(key);
    return value ? JSON.parse(value) : fallback;
  } catch {
    return fallback;
  }
}

function toast(message) {
  els.toast.textContent = message;
  els.toast.classList.add("is-visible");
  if (state.toastTimer) window.clearTimeout(state.toastTimer);
  state.toastTimer = window.setTimeout(() => els.toast.classList.remove("is-visible"), 1700);
}

function timeAgo(date) {
  const seconds = Math.max(0, Math.floor((Date.now() - date.getTime()) / 1000));
  if (seconds < 8) return "just now";
  if (seconds < 60) return `${seconds}s ago`;
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `${minutes}m ago`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h ago`;
  return date.toLocaleDateString(undefined, { month: "short", day: "numeric" });
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}
