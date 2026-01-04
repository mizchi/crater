// Import Crater layout engine (MoonBit compiled to JS)
import * as crater from '@crater';

const htmlInput = document.getElementById('html-input');
const jsonOutput = document.getElementById('json-output');
const canvas = document.getElementById('canvas');
const ctx = canvas.getContext('2d');
const widthInput = document.getElementById('width');
const heightInput = document.getElementById('height');
const renderBtn = document.getElementById('render-btn');
const preview = document.getElementById('preview');

function render() {
  const html = htmlInput.value;
  const width = parseInt(widthInput.value) || 400;
  const height = parseInt(heightInput.value) || 300;

  // Set canvas size
  canvas.width = width;
  canvas.height = height;

  try {
    // Get paint tree from Crater
    const paintTreeJson = crater.renderHtmlToPaintTree(html, width, height);
    const paintTree = JSON.parse(paintTreeJson);

    // Display JSON
    jsonOutput.textContent = JSON.stringify(paintTree, null, 2);

    // Render to canvas
    ctx.clearRect(0, 0, width, height);
    renderPaintNode(ctx, paintTree);
  } catch (e) {
    jsonOutput.textContent = 'Error: ' + e.message;
    console.error(e);
  }
}

function renderPaintNode(ctx, node, offsetX = 0, offsetY = 0) {
  const { x, y, width, height, backgroundColor, color, opacity, text, children } = node;

  // Calculate absolute position
  const absX = offsetX + x;
  const absY = offsetY + y;

  ctx.save();
  ctx.globalAlpha = opacity;

  // Draw background
  if (backgroundColor && backgroundColor !== 'rgba(0,0,0,0)') {
    ctx.fillStyle = backgroundColor;
    ctx.fillRect(absX, absY, width, height);
  }

  // Draw text (only for #text nodes)
  if (text && node.id === '#text') {
    // Default to white text for dark backgrounds
    ctx.fillStyle = (color && color !== 'rgba(0,0,0,1)') ? color : '#ffffff';
    ctx.font = '16px system-ui, sans-serif';
    ctx.fillText(text, absX + 2, absY + 14);
  }

  // Draw children with accumulated offset
  if (children) {
    for (const child of children) {
      renderPaintNode(ctx, child, absX, absY);
    }
  }

  ctx.restore();
}

// Initial render
render();

// Event listeners
renderBtn.addEventListener('click', render);
htmlInput.addEventListener('input', debounce(render, 500));
widthInput.addEventListener('change', render);
heightInput.addEventListener('change', render);

// Resize canvas container
function resizePreview() {
  const rect = preview.getBoundingClientRect();
  // Keep aspect ratio
}
window.addEventListener('resize', resizePreview);

function debounce(fn, delay) {
  let timer;
  return function(...args) {
    clearTimeout(timer);
    timer = setTimeout(() => fn.apply(this, args), delay);
  };
}

// Log available Crater functions
console.log('Crater functions:', Object.keys(crater));
