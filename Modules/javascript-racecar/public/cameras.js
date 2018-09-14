const port = 9001;
const ws =
    new window.WebSocket('ws://' + window.location.hostname + ':' + port);
ws.binaryType = 'arraybuffer';
var cur = {};
document.addEventListener("DOMContentLoaded", function(event) {

  const munpack = msgpack5().decode;

  // Camera and map images
  var img_camera = document.getElementById('camera');

  ws.onmessage = (e) => {
    // console.log(e.data);
    const msg = munpack(new Uint8Array(e.data));
    // console.log(msg);
    Object.assign(cur, msg);
    // console.log(cur);

  };

  const draw = (timestamp) => {
    window.requestAnimationFrame(drawPlot);
    const t = Date.now();
    const video3 = cur.video3;
    if (video3) {
      cur.video3 = false;
      const blobJ = new Blob([ video3['jpg'] ], {'type' : 'image/jpeg'});
      window.URL.revokeObjectURL(img_camera.src);
      img_camera.src = window.URL.createObjectURL(blobJ);
      // img_camera.onload = (e) => { console.log("done") };
      }
    const video1 = cur.video1;
    if (video1) {
      cur.video1 = false;
      const blobJ = new Blob([ video1['jpg'] ], {'type' : 'image/jpeg'});
      window.URL.revokeObjectURL(img_camera.src);
      img_camera.src = window.URL.createObjectURL(blobJ);
      // img_camera.onload = (e) => { console.log("done") };
      }
    const video2 = cur.video2;
    if (video2) {
      cur.video2 = false;
      const blobJ = new Blob([ video2['jpg'] ], {'type' : 'image/jpeg'});
      window.URL.revokeObjectURL(img_camera.src);
      img_camera.src = window.URL.createObjectURL(blobJ);
      // img_camera.onload = (e) => { console.log("done") };
    }
  };

  draw();
  window.addEventListener('resize', onWindowResize, false);
});
