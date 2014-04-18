// This file contains performance counters for RubyCLR. Lots of RubyCLR code contains dependencies
// on this file, but this file does not contain dependencies to other code.

#pragma once

namespace RubyClr {
  ref class PerformanceCounters {
    static PerformanceCounter^ _typeLookupCounter;
    static PerformanceCounter^ _typeLookupCacheHit;
    static PerformanceCounter^ _typeLookupCacheItems;

    static PerformanceCounters() {
      return;

      if (!PerformanceCounterCategory::Exists("RubyCLR")) {
        CounterCreationData^ ccd1 = gcnew CounterCreationData();
        ccd1->CounterName = "TypeLookups";
        ccd1->CounterHelp = "Total number of type lookups";
  
        CounterCreationData^ ccd2 = gcnew CounterCreationData();
        ccd2->CounterName = "TypeLookupCacheHits";
        ccd2->CounterHelp = "Total number of cache hits in lookup cache";

        CounterCreationData^ ccd3 = gcnew CounterCreationData();
        ccd3->CounterName = "TypeLookupCacheItems";
        ccd3->CounterHelp = "Total number of items in lookup cache";

        CounterCreationDataCollection^ collection = gcnew CounterCreationDataCollection();
        collection->Add(ccd1);
        collection->Add(ccd2);
        collection->Add(ccd3);

        PerformanceCounterCategory::Create("RubyCLR", "Performance counters for RubyCLR bridge", PerformanceCounterCategoryType::MultiInstance, collection);
      }

      _typeLookupCounter = gcnew PerformanceCounter("RubyCLR", "TypeLookups", false);
      _typeLookupCounter->RawValue = 0;

      _typeLookupCacheHit = gcnew PerformanceCounter("RubyCLR", "TypeLookupCacheHits", false);
      _typeLookupCacheHit->RawValue = 0;

      _typeLookupCacheItems = gcnew PerformanceCounter("RubyCLR", "TypeLookupCacheItems", false);
      _typeLookupCacheItems->RawValue = 0;
    }
  public:
    static void IncrementTypeLookups() {
      if (_typeLookupCounter != nullptr) _typeLookupCounter->Increment();
    }
    static void IncrementTypeLookupCacheHits() {
      if (_typeLookupCounter != nullptr) _typeLookupCacheHit->Increment();
    }
    static void IncrementTypeLookupCacheItems() {
      if (_typeLookupCounter != nullptr) _typeLookupCacheItems->Increment();
    }
  };
}