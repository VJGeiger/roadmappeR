// Makes the marker trace of the roadmap plot draggable and reports 
// each drop to Shiny as input$dragged = {id, date, nonce}.
// Called by htmlwidgets::onRender(); `data` = {markerTrace, ids}.
function(el, x, data) {
  var gd = el, dragging = null, hovered = null;
  var markerTrace = data.markerTrace;
  var DAY = 86400000;
  function xAx() { return gd._fullLayout.xaxis; }
  function toMs(clientX) {
    var rect = gd.getBoundingClientRect();
    var px = clientX - rect.left - gd._fullLayout._size.l;
    return xAx().p2c(px);
  }
  gd.on('plotly_hover', function(e) {
    for (var k = 0; k < e.points.length; k++) {
      if (e.points[k].curveNumber === markerTrace) {
        hovered = e.points[k].pointNumber; gd.style.cursor = 'ew-resize';
      }
    }
  });
  gd.on('plotly_unhover', function() { gd.style.cursor = ''; });
  gd.addEventListener('mousedown', function(ev) {
    if (hovered === null) return;
    // only start if the pointer is really on that marker
    var rect = gd.getBoundingClientRect();
    var mx = rect.left + gd._fullLayout._size.l +
             xAx().c2p(new Date(gd.data[markerTrace].x[hovered]).getTime());
    if (Math.abs(ev.clientX - mx) > 14) { hovered = null; return; }
    dragging = { idx: hovered, id: data.ids[hovered] };
    ev.preventDefault();
  }, true);
  window.addEventListener('mousemove', function(ev) {
    if (!dragging) return;
    var ms = Math.round(toMs(ev.clientX) / DAY) * DAY;
    var xs = gd.data[markerTrace].x.slice();
    xs[dragging.idx] = new Date(ms).toISOString().slice(0, 10);
    dragging.date = xs[dragging.idx];
    Plotly.restyle(gd, {x: [xs]}, [markerTrace]);
  });
  window.addEventListener('mouseup', function() {
    if (!dragging) return;
    var d = dragging; dragging = null; hovered = null; gd.style.cursor = '';
    if (d.date && window.Shiny) {
      Shiny.setInputValue('dragged', {id: d.id, date: d.date, nonce: Math.random()},
                          {priority: 'event'});
    }
  });
}
