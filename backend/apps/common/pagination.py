from rest_framework.pagination import CursorPagination


class CreatedAtCursorPagination(CursorPagination):
    """
    DRF's CursorPagination defaults to ordering by '-created', which
    doesn't match our models' created_at field name. This is the
    project-wide default — used wherever a model has a created_at
    field (Tweet, and later Notification, etc).
    """
    page_size = 20
    ordering = '-created_at'