type
  THandle = SizeInt;
  TThreadID = Pointer;
  TOSTimestamp = Int64;
  PRTLCriticalSection = ^TRTLCriticalSection;
  TRTLCriticalSection = record
    Data: array[0..3] of QWord;
  end;
