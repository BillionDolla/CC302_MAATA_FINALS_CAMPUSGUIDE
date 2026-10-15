const places = [
  {
    id: "sample:library",
    name: "Library",
    category: "academic",
    description: "Sample campus location. Update this pin to match your school.",
    x: 0.5,
    y: 0.15,
  },
  {
    id: "sample:main-building",
    name: "Main Building",
    category: "academic",
    description: "Sample campus location. Update this pin to match your school.",
    x: 0.5,
    y: 0.31,
  },
  {
    id: "sample:gymnasium",
    name: "Gymnasium",
    category: "recreation",
    description: "Sample campus location. Update this pin to match your school.",
    x: 0.22,
    y: 0.49,
  },
  {
    id: "sample:cafeteria",
    name: "Cafeteria",
    category: "food",
    description: "Sample campus location. Update this pin to match your school.",
    x: 0.78,
    y: 0.49,
  },
  {
    id: "sample:student-center",
    name: "Student Center",
    category: "services",
    description: "Sample campus location. Update this pin to match your school.",
    x: 0.5,
    y: 0.68,
  },
  {
    id: "sample:main-gate",
    name: "Main Gate",
    category: "other",
    description: "Sample campus location. Update this pin to match your school.",
    x: 0.5,
    y: 0.84,
  },
];

module.exports = (request, response) => {
  if (request.method !== "GET") {
    response.setHeader("Allow", "GET");
    return response.status(405).json({ error: "Method not allowed" });
  }

  response.setHeader("Cache-Control", "s-maxage=300, stale-while-revalidate=600");
  return response.status(200).json({ places });
};
