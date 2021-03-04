from traitlets import (
    Float,
    Int,
    Instance,
    HasTraits
)
from jupyterhub.traitlets import ByteSpecification


class ResourceAllocationTrait(Instance):

    def __init__(self, **kwargs):

        super(ResourceAllocationTrait, self).__init__(
              klass=ResourceAllocation, allow_none=True, **kwargs)


class ResourceAllocation(HasTraits):

    # The following traits about resources were imported from
    # https://github.com/jupyterhub/jupyterhub/blob/master/jupyterhub/spawner.py

    mem_limit = ByteSpecification(
        None,
        help="""
        Maximum number of bytes a single-user notebook server is allowed to use.

        Allows the following suffixes:
          - K -> Kilobytes
          - M -> Megabytes
          - G -> Gigabytes
          - T -> Terabytes

        If the single user server tries to allocate more memory than this,
        it will fail. There is no guarantee that the single-user notebook server
        will be able to allocate this much memory - only that it can not
        allocate more than this.
        """,
    ).tag(config=True)

    cpu_limit = Float(
        None,
        allow_none=True,
        help="""
        Maximum number of cpu-cores a single-user notebook server is allowed to use.

        If this value is set to 0.5, allows use of 50% of one CPU.
        If this value is set to 2, allows use of up to 2 CPUs.

        The single-user notebook server will never be scheduled by the kernel to
        use more cpu-cores than this. There is no guarantee that it can
        access this many cpu-cores.
        """,
    ).tag(config=True)

    mem_guarantee = ByteSpecification(
        None,
        help="""
        Minimum number of bytes a single-user notebook server is guaranteed to have available.

        Allows the following suffixes:
          - K -> Kilobytes
          - M -> Megabytes
          - G -> Gigabytes
          - T -> Terabytes
        """,
    ).tag(config=True)

    cpu_guarantee = Float(
        None,
        allow_none=True,
        help="""
        Minimum number of cpu-cores a single-user notebook server is guaranteed to have available.

        If this value is set to 0.5, allows use of 50% of one CPU.
        If this value is set to 2, allows use of up to 2 CPUs.
        """,
    ).tag(config=True)

    priority = Int(
        0,
        allow_none=True,
        help="""
        The priority value this settings if the user belong to
        more than one group.
        A smaller value means high priority.
        """
    )

    def __repr__(self):
        return ('{}(mem_limit={}, '
                'cpu_limit={}, '
                'mem_guarantee={}, '
                'cpu_guarantee={}, '
                'priority={})'.format(
                    self.__class__.__name__,
                    self.mem_limit,
                    self.cpu_limit,
                    self.mem_guarantee,
                    self.cpu_guarantee,
                    self.priority))
