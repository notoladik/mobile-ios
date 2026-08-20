#pragma once

#ifndef PROJECTM_CXX_EXPORT
#  if defined(PROJECTM_STATIC_DEFINE) || 1
#    define PROJECTM_CXX_EXPORT
#    define PROJECTM_CXX_NO_EXPORT
#  else
#    ifndef PROJECTM_CXX_EXPORT
#      ifdef projectM_EXPORTS
#        define PROJECTM_CXX_EXPORT __attribute__((visibility("default")))
#      else
#        define PROJECTM_CXX_EXPORT __attribute__((visibility("default")))
#      endif
#    endif
#    ifndef PROJECTM_CXX_NO_EXPORT
#      define PROJECTM_CXX_NO_EXPORT __attribute__((visibility("hidden")))
#    endif
#  endif
#endif

#ifndef PROJECTM_CXX_DEPRECATED
#  define PROJECTM_CXX_DEPRECATED __attribute__ ((__deprecated__))
#endif
