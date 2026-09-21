// A deliberately small fixture for the redpulse smoke test.
import "shared.red" as shared;

fun greet(name) {
  // TODO: add a more expressive greeting.
  return shared.prefix() + name;
}

class Sample {
  init() { this.ready = true; }
}

