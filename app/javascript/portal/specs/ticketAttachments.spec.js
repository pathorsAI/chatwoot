import {
  initializeTicketAttachments,
  formatFileSize,
} from '../ticketAttachments.js';

const MAX_SIZE = 10 * 1024 * 1024;

const buildFile = (name, type, size) => {
  const file = new File(['x'], name, { type });
  Object.defineProperty(file, 'size', { value: size });
  return file;
};

const renderForm = () => {
  document.body.innerHTML = `
    <span data-attachment-count>0 / 10</span>
    <div id="ticket-attachments"
         data-attachment-root
         data-max-files="10"
         data-max-size="${MAX_SIZE}"
         data-accept="image/*,application/pdf"
         data-error-count="Over the 10 file limit"
         data-error-size="Larger than 10 MB"
         data-error-type="File type not supported"
         data-remove-label="Remove file">
      <label data-attachment-dropzone>
        <input type="file" name="attachments[]" multiple data-attachment-input>
      </label>
      <ul data-attachment-list></ul>
    </div>
  `;

  const input = document.querySelector('[data-attachment-input]');
  Object.defineProperty(input, 'files', { writable: true, value: [] });
  initializeTicketAttachments();
  return input;
};

const pick = (input, files) => {
  input.files = files;
  input.dispatchEvent(new Event('change'));
};

const rows = () => document.querySelectorAll('[data-attachment-list] li');
const errorTexts = () =>
  [...document.querySelectorAll('[data-attachment-error]')].map(
    node => node.textContent
  );
const counterText = () =>
  document.querySelector('[data-attachment-count]').textContent;

describe('ticketAttachments', () => {
  beforeEach(() => {
    global.DataTransfer = class {
      constructor() {
        this.files = [];
        this.items = { add: file => this.files.push(file) };
      }
    };
    URL.createObjectURL = vi.fn(() => 'blob:preview');
    URL.revokeObjectURL = vi.fn();
  });

  it('formats file sizes', () => {
    expect(formatFileSize(512)).toBe('512 B');
    expect(formatFileSize(319488)).toBe('312 KB');
    expect(formatFileSize(1887436)).toBe('1.8 MB');
  });

  it('adds accepted files and hands them back to the input', () => {
    const input = renderForm();

    pick(input, [
      buildFile('screenshot.png', 'image/png', 319488),
      buildFile('trace.pdf', 'application/pdf', 1887436),
    ]);

    expect(rows()).toHaveLength(2);
    expect(input.files).toHaveLength(2);
    expect([...input.files].map(file => file.name)).toEqual([
      'screenshot.png',
      'trace.pdf',
    ]);
    expect(counterText()).toBe('2 / 10');
    expect(errorTexts()).toEqual([]);
  });

  it('rejects files beyond the count limit', () => {
    const input = renderForm();

    pick(
      input,
      Array.from({ length: 11 }, (_, index) =>
        buildFile(`shot-${index}.png`, 'image/png', 1024)
      )
    );

    expect(input.files).toHaveLength(10);
    expect(counterText()).toBe('10 / 10');
    expect(errorTexts()).toEqual(['Over the 10 file limit']);
  });

  it('rejects a file over the size limit', () => {
    const input = renderForm();

    pick(input, [
      buildFile('ok.png', 'image/png', 1024),
      buildFile('huge.png', 'image/png', MAX_SIZE + 1),
      buildFile('installer.exe', 'application/x-msdownload', 1024),
    ]);

    expect(input.files).toHaveLength(1);
    expect(counterText()).toBe('1 / 10');
    expect(errorTexts()).toEqual([
      'Larger than 10 MB',
      'File type not supported',
    ]);
  });

  it('removes a file from the selection', () => {
    const input = renderForm();
    pick(input, [
      buildFile('one.png', 'image/png', 1024),
      buildFile('two.pdf', 'application/pdf', 2048),
    ]);

    document.querySelector('[data-attachment-remove="0"]').click();

    expect(input.files).toHaveLength(1);
    expect([...input.files].map(file => file.name)).toEqual(['two.pdf']);
    expect(counterText()).toBe('1 / 10');
    expect(URL.revokeObjectURL).toHaveBeenCalledWith('blob:preview');
  });
});
