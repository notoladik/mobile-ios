#pragma once

#ifndef PROJECTM_EXPORT
#  if defined(PROJECTM_STATIC_DEFINE) || 1
#    define PROJECTM_EXPORT
#    define PROJECTM_NO_EXPORT
#  else
#    ifndef PROJECTM_EXPORT
#      ifdef projectM_EXPORTS
#        define PROJECTM_EXPORT __attribute__((visibility("default")))
#      else
#        define PROJECTM_EXPORT __attribute__((visibility("default")))
#      endif
#    endif
#    ifndef PROJECTM_NO_EXPORT
#      define PROJECTM_NO_EXPORT __attribute__((visibility("hidden")))
#    endif
#  endif
#endif

#ifndef PROJECTM_DEPRECATED
#  define PROJECTM_DEPRECATED __attribute__ ((__deprecated__))
#endif
