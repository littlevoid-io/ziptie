export interface DefaultConfigLeaf {
  path: string[];
  key: string;
  type: 'string' | 'boolean' | 'number' | 'array' | 'unknown';
}

export function getLeafProperties(obj: any, currentPath: string[] = []): DefaultConfigLeaf[] {
  let leaves: DefaultConfigLeaf[] = [];
  for (const key of Object.keys(obj)) {
    if (key === '$schema') continue;
    const val = obj[key];
    const newPath = [...currentPath, key];
    if (val !== null && typeof val === 'object' && !Array.isArray(val)) {
      leaves = leaves.concat(getLeafProperties(val, newPath));
    } else {
      let type: DefaultConfigLeaf['type'] = 'unknown';
      if (typeof val === 'boolean') type = 'boolean';
      else if (typeof val === 'number') type = 'number';
      else if (typeof val === 'string') type = 'string';
      else if (Array.isArray(val)) type = 'array';
      leaves.push({ path: newPath, key, type });
    }
  }
  return leaves;
}

export function getLeafPropertiesFromSchema(schema: any): DefaultConfigLeaf[] {
  const leaves: DefaultConfigLeaf[] = [];
  if (!schema || !schema.properties) return leaves;
  for (const catKey of Object.keys(schema.properties)) {
    if (catKey === '$schema') continue;
    const catSchema = schema.properties[catKey];
    if (catSchema && catSchema.properties) {
      for (const propKey of Object.keys(catSchema.properties)) {
        const prop = catSchema.properties[propKey];
        let type: DefaultConfigLeaf['type'] = 'unknown';
        if (prop.type === 'boolean') type = 'boolean';
        else if (prop.type === 'number') type = 'number';
        else if (prop.type === 'string') type = 'string';
        else if (prop.type === 'array') type = 'array';
        leaves.push({ path: [catKey, propKey], key: propKey, type });
      }
    }
  }
  return leaves;
}

export function castValue(value: any, targetType: DefaultConfigLeaf['type']): any {
  if (targetType === 'boolean') {
    if (value === 'true' || value === '1' || value === true || value === '') return true;
    if (value === 'false' || value === '0' || value === false) return false;
    return Boolean(value);
  }
  if (targetType === 'number') {
    const num = Number(value);
    return isNaN(num) ? value : num;
  }
  if (targetType === 'array') {
    if (Array.isArray(value)) return value;
    if (typeof value === 'string') {
      return value
        .split(',')
        .map(s => s.trim())
        .filter(Boolean);
    }
    return [value];
  }
  if (targetType === 'string') return String(value);
  return value;
}
