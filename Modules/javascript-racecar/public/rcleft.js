const port = 9001;
const ws =
    new window.WebSocket('ws://' + window.location.hostname + ':' + port);
ws.binaryType = 'arraybuffer';
const min = Math.min, max = Math.max, floor = Math.floor;
const to_jet = (v, a) => {
  // v is from 0 to 1
  // out is from 0 to 1
  // const fourValue = 4 * (1 - v);
  const fourValue = 4 * v;
  return "rgba(" +
         [
           floor(255 * min(fourValue - 1.5, 4.5 - fourValue)),
           floor(255 * min(fourValue - 0.5, 3.5 - fourValue)),
           floor(255 * min(fourValue + 0.5, 2.5 - fourValue)), a
         ].join() +
         ")";
};

const to_rainbow =
    (v, a) => { return 'hsla(' + floor(360 * v) + ', 100%, 50%, ' + a + ')'; };

const n_timesteps = 100;
var risk_over_time = [], risk_times = [];

document.addEventListener("DOMContentLoaded", function(event) {

  const d3colors = Plotly.d3.scale.category10();

  // Identifying the SVG size
  const environment_svg = document.getElementById('environment');
  var viewBox = environment_svg.getAttribute('viewBox').split(" ");
  var X_SVG_MIN = parseFloat(viewBox[0]), Y_SVG_MIN = parseFloat(viewBox[1]),
      X_SVG_SZ = parseFloat(viewBox[2]), Y_SVG_SZ = parseFloat(viewBox[3]);

  // Sizing the canvas
  // TODO: Recompute on resize
  const graph_canvas = document.getElementById('stage');
  var graph_ctx;
  var X_CANVAS_SZ, Y_CANVAS_SZ;
  const X_CANVAS_MIN = 0, Y_CANVAS_MIN = 0;
  var canvas_ready = false;
  const update_canvas = () => {
    var rect = environment_svg.getBoundingClientRect();
    X_CANVAS_SZ = graph_canvas.width = rect.width;
    Y_CANVAS_SZ = graph_canvas.height = rect.height;
    graph_ctx = graph_canvas.getContext('2d');
    // X_CANVAS_SZ = parseInt(graph_canvas.getAttribute('width'));
    // Y_CANVAS_SZ = parseInt(graph_canvas.getAttribute('height'));
    canvas_ready = true;
  };
  update_canvas();

  window.addEventListener('resize', () => {
    if (canvas_ready) {
      canvas_ready = false;
      window.requestAnimationFrame(update_canvas);
    }
  });

  const svg2canvas_sz = (s) => {
    return [ s[0] * X_CANVAS_SZ / X_SVG_SZ, s[1] * Y_CANVAS_SZ / Y_SVG_SZ ];
  };
  const svg2canvas = (p) => {
    return [
      X_CANVAS_SZ * (p[0] - X_SVG_MIN) / X_SVG_SZ + X_CANVAS_MIN,
      Y_CANVAS_SZ * (p[1] - Y_SVG_MIN) / Y_SVG_SZ + X_CANVAS_MIN
    ];
  };
  const coord2svg = (p) => { return [ p[0], -p[1] ]; };

  const munpack = msgpack5().decode;
  const observer_svg = document.getElementById('observers');
  const vehicles_svg = document.getElementById('vehicles');
  const obstacles_svg = document.getElementById('obstacles');
  const lanes_svg = document.getElementById('lanes');
  const info_div = document.getElementById('info');
  const graph_div = document.getElementById('graph');

  ws.onmessage = (e) => {
    // console.log(e.data);
    const msg = munpack(new Uint8Array(e.data));
    // console.log(msg);

    const observer = msg.observer;
    if (observer) {
      // Dots
      var obs_el = document.getElementById('observer');
      if (!obs_el) {
        obs_el =
            document.createElementNS("http://www.w3.org/2000/svg", 'circle');
        obs_el.setAttributeNS(null, 'id', 'observer');
        obs_el.setAttributeNS(null, 'class', 'observer');
        obs_el.setAttributeNS(null, 'r', 0.125);
        obs_el.style.fill = "#000";
        obs_el.style.stroke = "none";
        observer_svg.appendChild(obs_el);
        }
      const o = coord2svg(observer);
      obs_el.setAttributeNS(null, 'cx', o[0] || 0);
      obs_el.setAttributeNS(null, 'cy', o[1] || 0);
      }
    const vehicles = msg.vehicles;
    if (vehicles) {
      var vehicle_els = vehicles_svg.getElementsByClassName('vehicle');
      vehicles.map(coord2svg).forEach((v, i) => {
        var el = vehicle_els.item(i);
        if (!el) {
          el = document.createElementNS("http://www.w3.org/2000/svg", 'circle');
          el.setAttributeNS(null, 'class', 'vehicle');
          el.setAttributeNS(null, 'r', 0.125);
          el.style.fill = "#F00";
          el.style.stroke = "none";
          vehicles_svg.appendChild(el);
        }
        el.setAttributeNS(null, 'cx', v[0] || 0);
        el.setAttributeNS(null, 'cy', v[1] || 0);
      });
      }
    const obstacles = msg.obstacles;
    if (obstacles) {
      var obs_els = obstacles_svg.getElementsByClassName('obstacle');
      obstacles.forEach((l, i) => {
        const points =
            l.map((coord) => { return coord2svg(coord).join(); }).join(' ');
        var el = obs_els.item(i);
        if (!el) {
          el =
              document.createElementNS("http://www.w3.org/2000/svg", 'polygon');
          el.setAttributeNS(null, 'class', 'obstacle');
          el.style.fill = "#AAA";
          el.style.stroke = "#333";
          el.style.strokeWidth = "0.05";
          obstacles_svg.appendChild(el);
        }
        el.setAttributeNS(null, 'points', points);
      });
      }
    // const lanes = msg.lanes;
    // if (lanes) {
    //   var lanes_els = lanes_svg.getElementsByClassName('lane');
    //   lanes.forEach((l, i) => {
    //     const points =
    //         l.map((coord, i) => { return coord2svg(coord).join(); }).join('
    //         ');
    //     var el = lanes_els.item(i);
    //     if (!el) {
    //       el = document.createElementNS("http://www.w3.org/2000/svg",
    //                                     'polyline');
    //       el.setAttributeNS(null, 'class', 'lane');
    //       el.style.fill = "none";
    //       // el.style.stroke = "#0F0";
    //       el.style.stroke = d3colors(i);
    //       el.style.strokeWidth = "0.1";
    //       lanes_svg.appendChild(el);
    //     }
    //     el.setAttributeNS(null, 'points', points);
    //   });
    //   }

    // const beliefs = msg.beliefs;
    // const beliefs = msg.valid;
    // const beliefs = msg.attendant_risk;
    const beliefs = msg.unseen_risk;
    // const beliefs = msg.total_risk;
    const waypoints = msg.waypoints;
    if (beliefs && waypoints) {
      graph_ctx.clearRect(X_CANVAS_MIN, Y_CANVAS_MIN, X_CANVAS_SZ, Y_CANVAS_SZ);
      // Size of squares
      const s = svg2canvas_sz([ 0.075, 0.075 ]);
      var beliefs_els = lanes_svg.getElementsByClassName('belief');
      var counter = 0;
      beliefs.forEach((lb, il) => {
        const lwp = waypoints[il];
        lb = lb.map((b) => 1 / (1 - Math.log(b)));

        lb.forEach((b, i) => {
          // lb.forEach((b, i) => {
          const wp = coord2svg(lwp[i]);
          const p = svg2canvas([ wp[0], wp[1] ]);
          graph_ctx.fillStyle = to_jet(b, 0.75);
          // graph_ctx.fillStyle = to_rainbow(b, 0.75);
          graph_ctx.fillRect(p[0] - s[0] / 2, p[1] - s[0] / 2, s[0], s[1]);
          counter += 1;
        });
      });
      }

    const time = msg.t;
    if (time !== undefined) {
      info_div.innerHTML = time.toFixed(2);
      }
    const risk = msg.risk;
    if (time !== undefined && risk !== undefined) {
      // info_div.innerHTML = risk.toFixed(2);
      if (time < risk_times[risk_times.length - 1]) {
        risk_times = [];
        risk_over_time = [];
        }
      else if (risk_times.length >= n_timesteps) {
        risk_times.shift();
        risk_over_time.forEach((r) => { r.shift(); });
      }

      risk_times.push(time);
      risk.map((b) => 1 / (1 - Math.log(b))).forEach((r, i) => {
        // risk.forEach((r, i) => {
        if (i >= risk_over_time.length) {
          risk_over_time[i] = [ r ];
        } else {
          risk_over_time[i].push(r);
        }
      });

      var data = risk_over_time.map((r, i) => {
        return {
          x : risk_times,
          y : r,
          mode : 'lines',
          name : 'lane' + i,
          line : {color : d3colors(i)}
        };
      });
      data[data.length - 1].name = 'total';
      data[data.length - 1].line.color = d3colors(9);

      var layout = {
        title : 'Intersection Risk to Go',
        xaxis : {title : 'time', showgrid : false, zeroline : false},
        yaxis : {title : 'risk per meter', showline : false, range : [ 0, 1 ]},
        datarevision : time
      };
      Plotly.react(graph_div, data, layout);
      }

    if ('viewBox' in msg) {
      const changed = msg.viewBox.reduce(
          (eq, v, i) => { return eq || v !== viewBox[i]; }, false);
      if (changed) {
        // console.log("Changed viewBox", msg.viewBox, viewBox);
        viewBox = msg.viewBox;
        environment_svg.setAttribute('viewBox', viewBox.join(' '));
        X_SVG_MIN = parseFloat(viewBox[0]);
        Y_SVG_MIN = parseFloat(viewBox[1]);
        X_SVG_SZ = parseFloat(viewBox[2]);
        Y_SVG_SZ = parseFloat(viewBox[3]);
      }
    }
  };
});
