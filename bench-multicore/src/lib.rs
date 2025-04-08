#![cfg_attr(not(test), no_std)]

#[cfg(target_arch = "xtensa")]
mod xtensa;

use defmt::Format;

#[cfg(not(target_arch = "xtensa"))]
use ariel_os::bench::benchmark as benchmark_impl;
#[cfg(target_arch = "xtensa")]
use xtensa::benchmark as benchmark_impl;

#[derive(Debug, Format)]
pub enum Error {
    TimerWrapper,
    Migrated,
}

pub fn benchmark_complex<F: FnMut() -> ()>(iterations: usize, mut f: F) -> Result<usize, Error> {
    let mut total = 0;

    for _ in 0..iterations {
        total += benchmark(1, &mut f)?;
    }
    Ok(total / iterations)
}

pub fn benchmark<F: FnMut() -> ()>(iterations: usize, f: F) -> Result<usize, Error> {
    #[cfg(feature = "multicore")]
    let core = ariel_os::thread::core_id();

    let res = benchmark_impl(iterations, f).map_err(|_| Error::TimerWrapper);

    #[cfg(feature = "multicore")]
    if core != ariel_os::thread::core_id() {
        return Err(Error::Migrated);
    }
    res
}
