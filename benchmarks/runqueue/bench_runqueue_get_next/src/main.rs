#![no_main]
#![no_std]
#![feature(type_alias_impl_trait)]
#![feature(used_with_arg)]

use riot_rs::{
    debug::log::*,
    thread::{SCHED_PRIO_LEVELS, THREADS_NUMOF},
};
#[cfg(feature = "multicore-v1")]
use riot_rs_runqueue::{CoreId, GlobalRunqueue};
use riot_rs_runqueue::{RunQueue, RunqueueId, ThreadId};

#[riot_rs::thread(autostart)]
fn thread0() {
    let mut rq = RunQueue::<{ SCHED_PRIO_LEVELS }, { THREADS_NUMOF }>::new();
    rq.add(ThreadId::new(0), RunqueueId::new(5));
    match riot_rs::bench::benchmark(10000, || {
        #[cfg(not(feature = "multicore-v1"))]
        let next = rq.get_next();
        #[cfg(feature = "multicore-v1")]
        let next = rq.get_next(CoreId::new(0));

        core::hint::black_box(next);
        core::hint::black_box(&mut rq);
    }) {
        Ok(ticks) => info!("took {} ticks per iteration ", ticks),
        Err(_) => error!("benchmark returned error"),
    }
    loop {}
}
