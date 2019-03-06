from tornado import gen
from notebook.services.kernels.kernelmanager import MappingKernelManager
from traitlets import Int


class CoursewareKernelManager(MappingKernelManager):

    max_kernels = Int(
        None, config=True, allow_none=True,
        help="The maximum number of running kernels.")

    @gen.coroutine
    def start_kernel(self, kernel_id=None, path=None, **kwargs):

        kernel_id = yield gen.maybe_future(
            super(CoursewareKernelManager, self).start_kernel(
                kernel_id=kernel_id, path=path, **kwargs)
        )

        try:
            self.cull_kernels_if_exceed_num_limit()
        except Exception as e:
            self.log.exception("The following exception was encountered while checking the number of running kernels: %s", e)

        raise gen.Return(kernel_id)

    def cull_kernels_if_exceed_num_limit(self):
        if self.max_kernels is None:
            return

        self.log.debug("The number of running kernels is %d, limit is %d",
                       len(self._kernels), self.max_kernels)
        if len(self._kernels) > self.max_kernels:
            sorted_kernels = sorted(self._kernels.items(),
                                    reverse=True,
                                    key=lambda x: x[1].last_activity)

            while len(sorted_kernels) > self.max_kernels:
                kernel_id, kernel = sorted_kernels.pop()
                self.log.warning("The number of running kernels has exceeded limit. Culling kernel '%s' (%s) that last activity timestamp is oldest (%s)",
                                 kernel.kernel_name, kernel_id, kernel.last_activity)
                self.shutdown_kernel(kernel_id)
