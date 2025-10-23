/* Test suite for semaphore implementation
 *
 * This test suite verifies the correctness of the semaphore implementation
 * including edge cases, error conditions, and race condition scenarios.
 */

#include <linmo.h>

#include "private/error.h"

/* Test results tracking */
static int tests_passed = 0;
static int tests_failed = 0;

#define TEST_ASSERT(condition, description)    \
    do {                                       \
        if (condition) {                       \
            printf("PASS: %s\n", description); \
            tests_passed++;                    \
        } else {                               \
            printf("FAIL: %s\n", description); \
            tests_failed++;                    \
        }                                      \
    } while (0)

/* Test basic semaphore creation and destruction */
void test_semaphore_lifecycle(void)
{
    printf("\n=== Testing Semaphore Lifecycle ===\n");

    /* Test valid creation */
    sem_t *sem = mo_sem_create(5, 2);
    TEST_ASSERT(sem != NULL, "Create semaphore with valid parameters");
    TEST_ASSERT(mo_sem_getvalue(sem) == 2, "Initial count correct");

    /* Test destruction */
    TEST_ASSERT(mo_sem_destroy(sem) == ERR_OK, "Destroy empty semaphore");

    /* Test invalid parameters */
    TEST_ASSERT(mo_sem_create(0, 1) == NULL, "Reject zero max_waiters");
    TEST_ASSERT(mo_sem_create(5, -1) == NULL, "Reject negative initial count");
    TEST_ASSERT(mo_sem_create(5, SEM_MAX_COUNT + 1) == NULL,
                "Reject excessive initial count");

    /* Test NULL destruction */
    TEST_ASSERT(mo_sem_destroy(NULL) == ERR_OK,
                "Destroy NULL semaphore is no-op");
}

/* Test basic wait and signal operations */
void test_basic_operations(void)
{
    printf("\n=== Testing Basic Operations ===\n");

    sem_t *sem = mo_sem_create(5, 3);
    TEST_ASSERT(sem != NULL, "Create test semaphore");

    /* Test trywait on available semaphore */
    TEST_ASSERT(mo_sem_trywait(sem) == ERR_OK,
                "Trywait succeeds when resources available");
    TEST_ASSERT(mo_sem_getvalue(sem) == 2, "Count decremented after trywait");

    /* Test signal operation */
    mo_sem_signal(sem);
    TEST_ASSERT(mo_sem_getvalue(sem) == 3, "Count incremented after signal");

    /* Consume all resources */
    mo_sem_wait(sem); /* count = 2 */
    mo_sem_wait(sem); /* count = 1 */
    mo_sem_wait(sem); /* count = 0 */
    TEST_ASSERT(mo_sem_getvalue(sem) == 0, "All resources consumed");

    /* Test trywait on depleted semaphore */
    TEST_ASSERT(mo_sem_trywait(sem) == ERR_FAIL,
                "Trywait fails when no resources");

    /* Restore resources and cleanup */
    mo_sem_signal(sem);
    mo_sem_signal(sem);
    mo_sem_signal(sem);
    mo_sem_destroy(sem);
}

/* Test overflow protection */
void test_overflow_protection(void)
{
    printf("\n=== Testing Overflow Protection ===\n");

    sem_t *sem = mo_sem_create(5, SEM_MAX_COUNT);
    TEST_ASSERT(sem != NULL, "Create semaphore at max count");
    TEST_ASSERT(mo_sem_getvalue(sem) == SEM_MAX_COUNT,
                "Initial count at maximum");

    /* Signal should not cause overflow */
    int32_t initial_count = mo_sem_getvalue(sem);
    mo_sem_signal(sem);
    TEST_ASSERT(mo_sem_getvalue(sem) == initial_count,
                "Signal does not overflow max count");

    mo_sem_destroy(sem);
}

/* Test error conditions */
void test_error_conditions(void)
{
    printf("\n=== Testing Error Conditions ===\n");

    /* Test operations on NULL semaphore */
    TEST_ASSERT(mo_sem_getvalue(NULL) == -1,
                "getvalue returns -1 for NULL semaphore");
    TEST_ASSERT(mo_sem_waiting_count(NULL) == -1,
                "waiting_count returns -1 for NULL semaphore");
    TEST_ASSERT(mo_sem_trywait(NULL) == ERR_FAIL,
                "trywait fails for NULL semaphore");
}

/* Test FIFO ordering */
void test_fifo_ordering(void)
{
    printf("\n=== Testing FIFO Behavior ===\n");

    sem_t *sem = mo_sem_create(10, 0);
    TEST_ASSERT(sem != NULL, "Create semaphore for FIFO test");

    /* In a single-task environment, we can only test that trywait
     * respects the empty queue condition.
     */
    TEST_ASSERT(mo_sem_trywait(sem) == ERR_FAIL,
                "Trywait fails on empty semaphore");

    /* Add a resource */
    mo_sem_signal(sem);
    TEST_ASSERT(mo_sem_getvalue(sem) == 1,
                "Signal increments count when no waiters");

    /* Now trywait should succeed */
    TEST_ASSERT(mo_sem_trywait(sem) == ERR_OK, "Trywait succeeds after signal");

    mo_sem_destroy(sem);
}

/* Test binary semaphore (mutex-like) behavior */
void test_binary_semaphore(void)
{
    printf("\n=== Testing Binary Semaphore ===\n");

    sem_t *mutex = mo_sem_create(1, 1); /* Binary semaphore */
    TEST_ASSERT(mutex != NULL, "Create binary semaphore");
    TEST_ASSERT(mo_sem_getvalue(mutex) == 1, "Binary semaphore initial count");

    /* Acquire the mutex */
    mo_sem_wait(mutex);
    TEST_ASSERT(mo_sem_getvalue(mutex) == 0, "Mutex acquired");

    /* Try to acquire again (should fail) */
    TEST_ASSERT(mo_sem_trywait(mutex) == ERR_FAIL, "Second acquisition fails");

    /* Release the mutex */
    mo_sem_signal(mutex);
    TEST_ASSERT(mo_sem_getvalue(mutex) == 1, "Mutex released");

    /* Should be able to acquire again */
    TEST_ASSERT(mo_sem_trywait(mutex) == ERR_OK, "Can reacquire after release");

    mo_sem_signal(mutex); /* Release for cleanup */
    mo_sem_destroy(mutex);
}

/* Print test results */
void print_test_results(void)
{
    printf("\n=== Test Results ===\n");
    printf("Tests passed: %d\n", tests_passed);
    printf("Tests failed: %d\n", tests_failed);
    printf("Total tests: %d\n", tests_passed + tests_failed);
    printf("Overall: %s\n", (tests_failed == 0) ? "PASS" : "FAIL");

}

/* Simple idle task to prevent "no ready tasks" panic */
void idle_task(void)
{
    while (1)
        mo_task_wfi();
}

/* Task entry point for semaphore tests */
void semaphore_test_task(void)
{
    printf("Starting semaphore test suite...\n");

    test_semaphore_lifecycle();
    test_basic_operations();
    test_overflow_protection();
    test_error_conditions();
    test_fifo_ordering();
    test_binary_semaphore();

    print_test_results();

    printf("Semaphore tests completed successfully.\n");

    /* Test complete - go into low-activity mode */
    while (1)
        mo_task_wfi();
}

/* Example of how to integrate into app_main */
int32_t app_main(void)
{
    /* Create an idle task to prevent "no ready tasks" panic */
    int32_t idle_task_id = mo_task_spawn(idle_task, 512);
    if (idle_task_id < 0) {
        printf("Failed to create idle task\n");
        return 0;
    }

    /* Set idle task to lowest priority */
    mo_task_priority(idle_task_id, TASK_PRIO_IDLE);

    /* Create the test task */
    int32_t test_task_id = mo_task_spawn(semaphore_test_task, 1024);
    if (test_task_id < 0) {
        printf("Failed to create semaphore test task\n");
        return 0;
    }

    /* Enable preemptive scheduling */
    return 1;
}
