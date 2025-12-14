//---------------------------------------------------------------------------
//	Greenplum Database
//	Copyright (C) 2008 Greenplum, Inc.
//
//	@filename:
//		CRefCountTest.cpp
//
//	@doc:
//		Tests for CRefCount
//---------------------------------------------------------------------------

#include "gpos/base.h"
#include "gpos/common/CRefCount.h"
#include "gpos/common/clibwrapper.h"
#include "gpos/memory/CAutoMemoryPool.h"
#include "gpos/task/CAutoTraceFlag.h"
#include "gpos/test/CUnittest.h"

#include <new>

#include "unittest/gpos/common/CRefCountTest.h"

using namespace gpos;

//---------------------------------------------------------------------------
//	@function:
//		CRefCountTest::EresUnittest
//
//	@doc:
//		Unittest for ref-counting
//
//---------------------------------------------------------------------------
GPOS_RESULT
CRefCountTest::EresUnittest()
{

	CUnittest rgut[] =
		{
		GPOS_UNITTEST_FUNC(CRefCountTest::EresUnittest_CountUpAndDown),
		GPOS_UNITTEST_FUNC(CRefCountTest::EresUnittest_DeletableObjects)

#ifdef GPOS_DEBUG
		,
		GPOS_UNITTEST_FUNC(CRefCountTest::EresUnittest_Stack),
		GPOS_UNITTEST_FUNC(CRefCountTest::EresUnittest_Check)
#endif // GPOS_DEBUG
		};

	return CUnittest::EresExecute(rgut, GPOS_ARRAY_SIZE(rgut));
}


//---------------------------------------------------------------------------
//	@function:
//		CRefCountTest::EresUnittest_CountUpAndDown
//
//	@doc:
//		Simple count up and down of ref counted object
//
//---------------------------------------------------------------------------
GPOS_RESULT
CRefCountTest::EresUnittest_CountUpAndDown()
{
	// create memory pool
	CAutoMemoryPool amp;
	CMemoryPool *mp = amp.Pmp();

	// blank ref count object
	CRefCount *pref = GPOS_NEW(mp) CRefCount;

	// add counts
	for (ULONG i = 0; i < 10; i++)
	{
		pref->AddRef();
	}

	// release all additional refs
	for (ULONG i = 0; i < 10; i++)
	{
		pref->Release();
	}

	// destruct the object
	pref->Release();

	return GPOS_OK;
}

//---------------------------------------------------------------------------
//	@function:
//		CRefCountTest::EresUnittest_DeletableObjects
//
//	@doc:
//		Test deletable/undeletable objects
//
//---------------------------------------------------------------------------
GPOS_RESULT
CRefCountTest::EresUnittest_DeletableObjects()
{
	// create memory pool
	CAutoMemoryPool amp;
	CMemoryPool *mp = amp.Pmp();

	CAutoTraceFlag atfOOM(EtraceSimulateOOM, false);

	CDeletableTest *pdt = GPOS_NEW(mp) CDeletableTest;

	GPOS_TRY
	{
		// trying to release object here throws InvalidDeletion exception
		pdt->Release();
	}
	GPOS_CATCH_EX(ex)
	{
		if (!GPOS_MATCH_EX(ex, CException::ExmaSystem, CException::ExmiInvalidDeletion))
		{
			// unexpected exception -- rethrow it
			GPOS_RETHROW(ex);
		}

		GPOS_RESET_EX;
	}
	GPOS_CATCH_END;

	pdt->AllowDeletion();

	// now deletion is allowed
	pdt->Release();

	return GPOS_OK;
}


#ifdef GPOS_DEBUG

//---------------------------------------------------------------------------
//	@function:
//		CRefCountTest::EresUnittest_Stack
//
//	@doc:
//		Put CRefCount on stack -- this must assert in destructor
//
//---------------------------------------------------------------------------
GPOS_RESULT
CRefCountTest::EresUnittest_Stack()
{
	alignas(CRefCount) BYTE rgRef[sizeof(CRefCount)];
	CRefCount *pref = new (rgRef) CRefCount();
	BOOL assert_thrown = false;

	GPOS_TRY
	{
		// destructor guard must assert for non-zero ref count on stack
		GPOS_ASSERT(NULL == ITask::Self() ||
					ITask::Self()->HasPendingExceptions() ||
					0 == pref->RefCount());
	}
	GPOS_CATCH_EX(ex)
	{
		if (GPOS_MATCH_EX(ex, CException::ExmaSystem, CException::ExmiAssert))
		{
			assert_thrown = true;
			GPOS_RESET_EX;
		}
		else
		{
			GPOS_RETHROW(ex);
		}
	}
	GPOS_CATCH_END;

	// reset refcount to make the stack object benign after the assertion
	*reinterpret_cast<ULONG_PTR*>(pref) = 0;

	return assert_thrown ? GPOS_OK : GPOS_FAILED;
}



//---------------------------------------------------------------------------
//	@function:
//		CRefCountTest::EresUnittest_Check
//
//	@doc:
//		Call AddRef on a deleted ref count; this test is quite experimental;
//
//---------------------------------------------------------------------------
GPOS_RESULT
CRefCountTest::EresUnittest_Check()
{
	alignas(CRefCount) BYTE rgRef[sizeof(CRefCount)];
	CRefCount *pref = new (rgRef) CRefCount();
	clib::Memset(rgRef, GPOS_MEM_FREED_PATTERN_CHAR, sizeof(rgRef));

	BOOL assert_thrown = false;

	GPOS_TRY
	{
		pref->AddRef();
	}
	GPOS_CATCH_EX(ex)
	{
		if (GPOS_MATCH_EX(ex, CException::ExmaSystem, CException::ExmiAssert))
		{
			assert_thrown = true;
			GPOS_RESET_EX;
		}
		else
		{
			GPOS_RETHROW(ex);
		}
	}
	GPOS_CATCH_END;

	return assert_thrown ? GPOS_OK : GPOS_FAILED;
}

#endif // GPOS_DEBUG

// EOF
