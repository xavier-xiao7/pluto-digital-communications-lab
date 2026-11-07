# Dependencies and provenance

This project grew from a university digital communications laboratory exercise. The published implementation expands the basic modulation/channel/detection exercise with synchronization, binary framing, coding, visual inspection and two-radio operation.

The MIT license covers the project source distributed here. Original course handouts, supplied course model binaries, report templates and teaching recordings are not redistributed. The public model builders assemble fresh diagrams using library blocks from the user's installed MATLAB products.

| Dependency | Use | Distribution |
|---|---|---|
| MATLAB and Simulink | Programming, UI, block models and simulation | Install and license separately through MathWorks |
| Communications Toolbox | Channel blocks, pulse shaping and communication functions | MathWorks product; not bundled |
| DSP System Toolbox | Frame-based signal sources and spectrum display | MathWorks product; not bundled |
| Signal Processing Toolbox | Filtering and resampling | MathWorks product; not bundled |
| ADALM-Pluto support package and ADI driver | Host/radio interface | Install from the official providers; not bundled |
| ADALM-Pluto firmware | Device operation | Supplied with/configured on the device; not bundled |

The example PNG and WAV fixtures are generated procedurally by project source. No university logo, third-party photograph or recorded audio is included. The hardware folders contain project-local copies of protocol and receiver helpers, under the same project license.

Product names identify compatible equipment and software. This repository is not an official MathWorks or Analog Devices product.
