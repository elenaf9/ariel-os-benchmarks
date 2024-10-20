#![no_main]
#![no_std]
#![feature(type_alias_impl_trait)]
#![feature(used_with_arg)]

use riot_rs::{debug::log::*, thread};

#[riot_rs::thread(autostart)]
fn thread0() {
    match bench_multicore::benchmark(10000, || thread::schedule()) {
        Ok(ticks) => info!("took {} ticks per iteration", ticks),

        Err(err) => error!("benchmark error: {}", err),
    }
    loop {}
}
