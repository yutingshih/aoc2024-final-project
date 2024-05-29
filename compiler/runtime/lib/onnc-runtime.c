#include <onnc-runtime-internal.h>

#include <assert.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

// #include <unistd.h>
// #include <sys/stat.h> 
// #include <fcntl.h>
// #include <sys/mman.h>

void *ONNC_RUNTIME_init_runtime() {
  Context *context = (Context *)calloc(1 , sizeof(Context));
  // XXX: design!
  context->mem = (void **)calloc(2048 , sizeof(void *));
  context->mem_i = 0;

  return context;
}

bool ONNC_RUNTIME_shutdown_runtime(void *onnc_runtime_context) {
  if (onnc_runtime_context == NULL) {
    return true;
  }

  Context *context = (Context *)onnc_runtime_context;
  for (size_t i = 0; i < context->mem_i; ++i) {
    free(context->mem[i]);
  }

  free(context->mem);
  free(context);
  return true;
}

/* core library */

bool ONNC_RUNTIME_has_tensor(const struct ONNC_RUNTIME_tensor_offset_table* table, uint64_t tensor)
{
  if (table == NULL) {
    return false;
  }

  return tensor < table->number_of_tensors;
}

struct ONNC_RUNTIME_tensor_offset ONNC_RUNTIME_get_tensor_offset(const struct ONNC_RUNTIME_tensor_offset_table* table,
                                                                 uint64_t                                       tensor)
{
  assert(ONNC_RUNTIME_has_tensor(table, tensor));

  return table->tensor_offsets[tensor];
}

/* client library */

const struct ONNC_RUNTIME_tensor_offset_table*
ONNC_RUNTIME_read_tensor_offset_table(struct ONNC_RUNTIME_tensor_file* file)
{
  if (file == NULL) {
    return NULL;
  }

  return file->data;
}

struct ONNC_RUNTIME_tensor_view ONNC_RUNTIME_read_tensor(struct ONNC_RUNTIME_tensor_file* file, uint64_t tensor)
{
  if (file == NULL) {
    const struct ONNC_RUNTIME_tensor_view tensor_view = {.data = NULL, .size = 0};
    return tensor_view;
  }

  const struct ONNC_RUNTIME_tensor_offset_table* const table = ONNC_RUNTIME_read_tensor_offset_table(file);
  if (!ONNC_RUNTIME_has_tensor(table, tensor)) {
    const struct ONNC_RUNTIME_tensor_view tensor_view = {.data = NULL, .size = 0};
    return tensor_view;
  }

  const struct ONNC_RUNTIME_tensor_offset tensor_offset = ONNC_RUNTIME_get_tensor_offset(table, tensor);
  const struct ONNC_RUNTIME_tensor_view   tensor_view   = {.data = (char*)file->data + tensor_offset.offset,
                                                       .size = tensor_offset.size};
  return tensor_view;
}
