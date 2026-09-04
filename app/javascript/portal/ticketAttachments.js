const BYTES_PER_UNIT = 1024;
const SIZE_UNITS = ['KB', 'MB', 'GB'];

export const formatFileSize = bytes => {
  if (bytes < BYTES_PER_UNIT) return `${bytes} B`;

  let value = bytes / BYTES_PER_UNIT;
  let unit = 0;
  while (value >= BYTES_PER_UNIT && unit < SIZE_UNITS.length - 1) {
    value /= BYTES_PER_UNIT;
    unit += 1;
  }
  return `${value < 10 ? value.toFixed(1) : Math.round(value)} ${SIZE_UNITS[unit]}`;
};

const matchesAccept = (file, accept) =>
  accept.some(rule =>
    rule.endsWith('/*')
      ? file.type.startsWith(rule.slice(0, -1))
      : file.type === rule
  );

const extensionLabel = file =>
  file.name.includes('.')
    ? file.name.split('.').pop().slice(0, 4).toUpperCase()
    : '?';

const buildThumbnail = entry => {
  if (entry.previewUrl) {
    const image = document.createElement('img');
    image.src = entry.previewUrl;
    image.alt = '';
    image.className =
      'w-9 h-9 rounded object-cover border border-solid border-zinc-200 dark:border-zinc-800 flex-shrink-0';
    return image;
  }

  const box = document.createElement('span');
  box.className =
    'flex items-center justify-center flex-shrink-0 rounded w-9 h-9 bg-zinc-100 dark:bg-zinc-800 text-[10px] font-semibold text-zinc-500 dark:text-zinc-400';
  box.textContent = extensionLabel(entry.file);
  return box;
};

const buildRow = (file, extraClass) => {
  const row = document.createElement('li');
  row.className = `flex items-center gap-2.5 px-2.5 py-1.5 text-xs border border-solid rounded-md ${extraClass}`;

  const name = document.createElement('span');
  name.className = 'flex-1 truncate text-zinc-900 dark:text-zinc-100';
  name.textContent = file.name;
  row.appendChild(name);

  return row;
};

export const initializeTicketAttachments = () => {
  const root = document.querySelector('[data-attachment-root]');
  if (!root) return;

  const input = root.querySelector('[data-attachment-input]');
  const list = root.querySelector('[data-attachment-list]');
  const dropzone = root.querySelector('[data-attachment-dropzone]');
  const counter = document.querySelector('[data-attachment-count]');

  const maxFiles = Number(root.dataset.maxFiles);
  const maxSize = Number(root.dataset.maxSize);
  const accept = root.dataset.accept.split(',');
  const messages = {
    count: root.dataset.errorCount,
    size: root.dataset.errorSize,
    type: root.dataset.errorType,
  };

  const accepted = [];
  let rejected = [];

  // The input keeps owning the files, so the plain multipart submit carries them.
  const syncInput = () => {
    const transfer = new DataTransfer();
    accepted.forEach(entry => transfer.items.add(entry.file));
    input.files = transfer.files;
  };

  const buildAcceptedRow = (entry, index) => {
    const row = buildRow(entry.file, 'border-zinc-200 dark:border-zinc-800');
    row.prepend(buildThumbnail(entry));

    const size = document.createElement('span');
    size.className = 'text-zinc-500 dark:text-zinc-400';
    size.textContent = formatFileSize(entry.file.size);
    row.appendChild(size);

    const remove = document.createElement('button');
    remove.type = 'button';
    remove.className =
      'cursor-pointer text-zinc-500 dark:text-zinc-400 hover:text-zinc-900 dark:hover:text-zinc-100';
    remove.setAttribute('aria-label', root.dataset.removeLabel);
    remove.dataset.attachmentRemove = index;
    remove.textContent = '×';
    row.appendChild(remove);

    return row;
  };

  const buildRejectedRow = entry => {
    const row = buildRow(entry.file, 'border-red-400');
    row.prepend(buildThumbnail({ file: entry.file, previewUrl: null }));

    const message = document.createElement('span');
    message.className = 'text-red-500';
    message.dataset.attachmentError = '';
    message.textContent = entry.message;
    row.appendChild(message);

    return row;
  };

  const render = () => {
    list.replaceChildren();
    accepted.forEach((entry, index) =>
      list.appendChild(buildAcceptedRow(entry, index))
    );
    rejected.forEach(entry => list.appendChild(buildRejectedRow(entry)));
    counter.textContent = `${accepted.length} / ${maxFiles}`;
  };

  const removeAt = index => {
    const [entry] = accepted.splice(index, 1);
    if (entry.previewUrl) URL.revokeObjectURL(entry.previewUrl);
    rejected = [];
    syncInput();
    render();
  };

  const addFiles = files => {
    rejected = [];
    Array.from(files).forEach(file => {
      if (accepted.length >= maxFiles) {
        rejected.push({ file, message: messages.count });
        return;
      }
      if (file.size > maxSize) {
        rejected.push({ file, message: messages.size });
        return;
      }
      if (!matchesAccept(file, accept)) {
        rejected.push({ file, message: messages.type });
        return;
      }
      accepted.push({
        file,
        previewUrl: file.type.startsWith('image/')
          ? URL.createObjectURL(file)
          : null,
      });
    });
    syncInput();
    render();
  };

  list.addEventListener('click', event => {
    const button = event.target.closest('[data-attachment-remove]');
    if (button) removeAt(Number(button.dataset.attachmentRemove));
  });

  input.addEventListener('change', () => {
    const picked = Array.from(input.files || []);
    if (picked.length) addFiles(picked);
  });

  ['dragenter', 'dragover'].forEach(name =>
    dropzone.addEventListener(name, event => {
      event.preventDefault();
      dropzone.classList.add('border-n-portal');
    })
  );

  ['dragleave', 'drop'].forEach(name =>
    dropzone.addEventListener(name, event => {
      event.preventDefault();
      dropzone.classList.remove('border-n-portal');
    })
  );

  dropzone.addEventListener('drop', event =>
    addFiles(event.dataTransfer.files)
  );

  render();
};

export const initializeTicketCounters = () => {
  document.querySelectorAll('[data-counter-target]').forEach(field => {
    const target = document.querySelector(field.dataset.counterTarget);
    const update = () => {
      target.textContent = `${field.value.length.toLocaleString()} / ${field.maxLength.toLocaleString()}`;
    };
    field.addEventListener('input', update);
    update();
  });
};
