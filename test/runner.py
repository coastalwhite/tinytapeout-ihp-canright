import os
from pathlib import Path

from cocotb_tools.runner import get_runner


def test_my_design_runner():
    sim = os.getenv("SIM", "icarus")

    proj_path = Path(__file__).resolve().parent

    sources = [proj_path / "tb.v", proj_path.parent / "src" / "project.v"]

    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="tt_um_coastalwhite_canright_sbox",
    )

    runner.test(
        hdl_toplevel="tt_um_coastalwhite_canright_sbox",
        test_module="test,",
        timescale=("1ns", "1ps"),
    )


if __name__ == "__main__":
    test_my_design_runner()
