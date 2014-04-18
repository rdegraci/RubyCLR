#include "stdafx.h"

#pragma warning(disable:4947)

VALUE g_module, g_generator;
VALUE g_big_decimal_class;
VALUE g_ruby_object_handles;
VALUE g_ruby_identity_map;

#include "RubyHelpers.h"
#include "PerfCounters.h"
#include "Marshal.h"
#include "Wrappers.h"
#include "Reflection.h"
#include "Utility.h"
#include "TestTargets.h"
#include "Databinding.h"
#include "Core.h"
