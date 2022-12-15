class PycamBaseException(Exception):
    pass


class AbortOperationException(PycamBaseException):
    pass


class CommunicationError(PycamBaseException):
    pass


class InitializationError(PycamBaseException):
    pass


class InvalidDataError(PycamBaseException):
    pass


class MissingAttributeError(InvalidDataError):
    pass


class AmbiguousDataError(InvalidDataError):
    pass


class UnexpectedAttributeError(InvalidDataError):
    pass


class InvalidKeyError(InvalidDataError):

    def __init__(self, invalid_key, choice_enum):
        # retrieve the pretty name of the enum
        enum_name = str(choice_enum).split("'")[1]
        super().__init__("Unknown {}: {} (should be one of: {})".format(
            enum_name, invalid_key, ", ".join([item.value for item in choice_enum])))


class LoadFileError(PycamBaseException):
    pass


class MissingDependencyError(PycamBaseException):
    """ a dependency (e.g. an external python module) is missing """
