# Long-running EGL/Vulkan clients probe every EGL vendor and Vulkan ICD at
# startup; NVIDIA's keep /dev/nvidia* open, which blocks RTD3 so the dGPU never
# powers off. Restrict such processes to Mesa/Intel.
{
  __EGL_VENDOR_LIBRARY_FILENAMES = "/run/opengl-driver/share/glvnd/egl_vendor.d/50_mesa.json";
  VK_DRIVER_FILES = "/run/opengl-driver/share/vulkan/icd.d/intel_icd.x86_64.json";
}
