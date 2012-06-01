// use the newer alsa api
#define ALSA_PCM_NEW_HW_PARAMS_API
#include <alsa/asoundlib.h>

#include <math.h>
#include <stdio.h>
#include <signal.h>
#include <unistd.h>
#include <fcntl.h>
#include <pthread.h>

#include "sound_params.h"
#include "alsa_util.h"
#include "dtmf.h"

// thread variables
static pthread_t rxthread;

// transmitter and reciever handles
snd_pcm_t *tx;
snd_pcm_t *rx;
// transmitter and reciever parameter objects
snd_pcm_hw_params_t *txParams;
snd_pcm_hw_params_t *rxParams;

// current audio frame number
//static long frameNumber = 0;

// receive buffer
//short rxBuffer[PSAMPLE];
short rxBuffer[2*PSAMPLE];
// number of frames in buffer
int nrxFrames = 0;
// current buffer index
int irxBuffer = 0;

int open_transmitter() {
  // open transmitter (speakers)
  int ret = snd_pcm_open(&tx, "default", SND_PCM_STREAM_PLAYBACK, 0);
  if (ret < 0) {
    fprintf(stderr, "unable to open transmitter pcm device: %s\n", snd_strerror(ret));
    exit(1);
  }

  return 0;
}

int open_receiver() {
  // open receiver (microphones)
  int ret = snd_pcm_open(&rx, "default", SND_PCM_STREAM_CAPTURE, 0);
  if (ret < 0) {
    fprintf(stderr, "unable to open receiver pcm device: %s\n", snd_strerror(ret));
    exit(1);
  }

  return 0;
}

int init_devices() {
  print_alsa_lib_version();

  // open devices
  open_transmitter();
  open_receiver();

  // allocate parameter objects
  printf("opening transmitter audio device..."); fflush(stdout);
  snd_pcm_hw_params_alloca(&txParams);
  printf("done\n");
  printf("opening reciever audio device..."); fflush(stdout);
  snd_pcm_hw_params_alloca(&rxParams);
  printf("done\n");

  // set parameters
  printf("setting transmitter parameters..."); fflush(stdout);
  set_device_params(tx, txParams);
  printf("done\n");
  print_device_params(tx, txParams, 0); 

  printf("setting receiver parameters..."); fflush(stdout);
  set_device_params(rx, rxParams);
  printf("done\n");
  print_device_params(rx, rxParams, 0); 
}


void *sound_comm_rx_thread_func(void*) {

  printf("starting SoundComm receiver thread\n");

  sigset_t sigs;
  sigfillset(&sigs);
  pthread_sigmask(SIG_BLOCK, &sigs, NULL);

  snd_pcm_uframes_t frames = NFRAME;

  nrxFrames = 0;
  irxBuffer = 0;
  while (1) {

    if (nrxFrames + frames < PFRAME) {
      // all frames fit within buffer, read all available frames
      int rframes = snd_pcm_readi(rx, rxBuffer+irxBuffer, frames);
      if (rframes == -EPIPE) {
        // EPIPE mean overrun
        fprintf(stderr, "overrun occurred\n");
        snd_pcm_prepare(rx);
        // reset rx buffer
        irxBuffer = 0;
        continue;
      } else if (rframes < 0) {
        fprintf(stderr, "error from read: %s\n", snd_strerror(rframes));
        // reset rx buffer
        irxBuffer = 0;
        continue;
      } else if (rframes != (int)frames) {
        fprintf(stderr, "short read: read %d frames\n", rframes);
        // reset rx buffer
        irxBuffer = 0;
        continue;
      } 
      
      // update rx buffer
      nrxFrames += rframes;
      irxBuffer += rframes * SAMPLES_PER_FRAME;

    } else {
      // read enough frames to fill buffer
      int nframes = PFRAME - nrxFrames;
      int rframes = snd_pcm_readi(rx, rxBuffer+irxBuffer, nframes);
      if (rframes == -EPIPE) {
        // EPIPE mean overrun
        fprintf(stderr, "overrun occurred\n");
        snd_pcm_prepare(rx);
        // reset rx buffer
        irxBuffer = 0;
        continue;
      } else if (rframes < 0) {
        fprintf(stderr, "error from read: %s\n", snd_strerror(rframes));
        // reset rx buffer
        irxBuffer = 0;
        continue;
      } else if (rframes != (int)nframes) {
        fprintf(stderr, "short read: read %d frames\n", rframes);
        // reset rx buffer
        irxBuffer = 0;
        continue;
      } 
      // process audio sample
      check_tone(rxBuffer);

      // read remaining audio from buffer
      nframes = NFRAME - rframes;
      rframes = snd_pcm_readi(rx, rxBuffer, nframes);
      if (rframes == -EPIPE) {
        // EPIPE mean overrun
        fprintf(stderr, "overrun occurred\n");
        snd_pcm_prepare(rx);
        // reset rx buffer
        irxBuffer = 0;
        continue;
        
      } else if (rframes < 0) {
        fprintf(stderr, "error from read: %s\n", snd_strerror(rframes));
        // reset rx buffer
        irxBuffer = 0;
        continue;

      } else if (rframes != (int)nframes) {
        fprintf(stderr, "short read: read %d frames\n", rframes);
        // reset rx buffer
        irxBuffer = 0;
        continue;

      } 

      // update rx buffer
      nrxFrames = rframes;
      irxBuffer = rframes * SAMPLES_PER_FRAME;
    }

    pthread_testcancel();
  }
}


void sound_comm_rx_thread_cleanup() {

  // stop the thread if needed
  if (rxthread) {
    pthread_cancel(rxthread);
    usleep(500000L);
  }

  // clear any pending buffers
  snd_pcm_drain(rx);

  // close device
  printf("closing receiver device..."); fflush(stdout);
  snd_pcm_close(tx);
  printf("done\n");
}



int main() {
  int ret;

  // initialize audio devices (transmitter and receiver)
  init_devices();

  // start each camera thread
  printf("starting sound receiver thread\n");
  ret = pthread_create(&rxthread, NULL, sound_comm_rx_thread_func, NULL);
  if (ret != 0) {
    printf("error creating receiver pthread: %d\n", ret);
    return -1;
  }

  snd_pcm_uframes_t frames = NFRAME;

  short pcm[2*NFRAME*SAMPLES_PER_FRAME];
  double t = 0;
  double f1 = 697;
  double f2 = 1209;
  while (1) {
    t = 0.0;
    for (int i = 0; i < NFRAME; i++) {
      t += 1.0/16000.0;
      pcm[2*i] = (short) (500.0 * sin(2*M_PI*f1*t) + 500.0 * sin(2*M_PI*f2*t));
      //pcm[2*i+1] = 0;
      pcm[2*i+1] = (short) (500.0 * sin(2*M_PI*f1*t) + 500.0 * sin(2*M_PI*f2*t));
    }

    int rc = snd_pcm_writei(tx, pcm, frames);
    if (rc == -EPIPE) {
      // EPIPE mean underrun
      fprintf(stderr, "underrun occurred\n");
      snd_pcm_prepare(tx);
    } else if (rc < 0) {
      fprintf(stderr, "error from writei: %s\n", snd_strerror(rc));
    } else if (rc != (int)frames) {
      fprintf(stderr, "short write, write %d frames\n", rc);
    }
  }


  pthread_join(rxthread, NULL);

  snd_pcm_drain(tx);

  printf("closing transmitter device..."); fflush(stdout);
  snd_pcm_close(rx);
  printf("done\n");

  return 0;
}


